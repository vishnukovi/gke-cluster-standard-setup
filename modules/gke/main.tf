# ==============================================================================
# GKE Module
# Creates a private, hardened GKE cluster with:
#   - VPC-native networking (alias IPs)
#   - Private nodes (no external IPs on nodes)
#   - Workload Identity (replaces service account key files)
#   - Dataplane V2 / ADVANCED_DATAPATH (eBPF, built-in network policy)
#   - Release channel (automated, tested Kubernetes upgrades)
#   - Vertical Pod Autoscaler
#   - Managed Prometheus (GMP)
#   - Shielded nodes (Secure Boot + Integrity Monitoring)
#   - Separate system and application node pools
#   - Cluster Autoscaler on the application node pool
#   - Binary Authorization (optional — recommended for prod)
# ==============================================================================

locals {
  cluster_name = "${var.environment}-gke-cluster"
}

resource "google_container_cluster" "primary" {
  name        = local.cluster_name
  project     = var.project_id
  location    = var.location
  description = "GKE cluster for the ${var.environment} environment"

  # Always manage node pools via separate resources for full control
  remove_default_node_pool = true
  initial_node_count       = 1

  # ── Networking ────────────────────────────────────────────────────────────

  network    = var.vpc_name
  subnetwork = var.subnet_name

  # VPC-native: nodes/pods/services get alias IPs from subnet secondary ranges
  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private cluster: nodes get RFC-1918 IPs only, no external IPs
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Whitelist CIDRs that can reach the Kubernetes API server
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  # ── Upgrades ─────────────────────────────────────────────────────────────

  # Release channel: GKE manages version selection + automatic upgrades
  release_channel {
    channel = var.release_channel # RAPID (dev) | REGULAR (prod)
  }

  # Schedule upgrades during low-traffic windows
  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start_time
      end_time   = var.maintenance_end_time
      recurrence = var.maintenance_recurrence
    }
  }

  # ── Identity & Security ───────────────────────────────────────────────────

  # Workload Identity: lets K8s SAs authenticate as GCP SAs (no key files)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Shielded nodes: protect against rootkit/bootkit attacks at boot time
  enable_shielded_nodes = true

  # Dataplane V2 (eBPF): better observability, built-in network policy enforcement
  datapath_provider = "ADVANCED_DATAPATH"

  # Binary Authorization: only allow images that pass attestation policy
  dynamic "binary_authorization" {
    for_each = var.enable_binary_authorization ? [1] : []
    content {
      evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
    }
  }

  # ── Add-ons ──────────────────────────────────────────────────────────────

  addons_config {
    # Ingress-based L7 HTTP load balancing
    http_load_balancing {
      disabled = false
    }

    # Horizontal Pod Autoscaler support
    horizontal_pod_autoscaling {
      disabled = false
    }

    # Calico not needed — Dataplane V2 handles network policy natively
    network_policy_config {
      disabled = true
    }

    # NodeLocal DNSCache: reduces DNS latency by caching on each node
    dns_cache_config {
      enabled = true
    }

    # CSI driver for persistent disks (required for StatefulSets)
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }

    # CSI driver for Cloud Storage FUSE mounts
    gcs_fuse_csi_driver_config {
      enabled = true
    }

    # CSI driver for Filestore (NFS-like shared volumes)
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  # Cloud DNS for cluster-internal DNS (more scalable than kube-dns/CoreDNS)
  dns_config {
    cluster_dns       = "CLOUD_DNS"
    cluster_dns_scope = "CLUSTER_SCOPE"
  }

  # ── Scaling ──────────────────────────────────────────────────────────────

  # Vertical Pod Autoscaler: automatically right-size CPU/memory requests
  vertical_pod_autoscaling {
    enabled = true
  }

  # ── Observability ─────────────────────────────────────────────────────────

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]

    # Managed Prometheus: GKE-integrated Prometheus without self-hosting
    managed_prometheus {
      enabled = true
    }
  }

  # ── Miscellaneous ─────────────────────────────────────────────────────────

  # Maximum pods per node — affects how many nodes the cluster autoscaler adds
  default_max_pods_per_node = 110

  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }
}

# ==============================================================================
# System Node Pool
# Dedicated to cluster-critical add-ons (CoreDNS, metrics-server, kube-proxy…)
# Tainted with CriticalAddonsOnly=true:NoSchedule so user workloads can't land here.
# ==============================================================================

resource "google_container_node_pool" "system" {
  name     = "${local.cluster_name}-system"
  project  = var.project_id
  location = var.location
  cluster  = google_container_cluster.primary.name

  # Fixed size — system components need stable, predictable capacity
  node_count = var.system_node_count

  node_config {
    machine_type    = var.system_machine_type
    disk_size_gb    = 50
    disk_type       = "pd-ssd"
    image_type      = "COS_CONTAINERD" # Hardened, minimal OS from Google
    service_account = var.node_service_account_email

    # Cloud Platform scope: fine-grained access is controlled via IAM, not scopes
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    # Use GKE Metadata Server instead of instance metadata (blocks SSRF to IMDS)
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Shielded node settings — must match cluster-level enable_shielded_nodes
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = merge(var.node_labels, {
      "environment" = var.environment
      "node-pool"   = "system"
      "managed-by"  = "terraform"
    })

    # Prevent user workloads from scheduling on the system pool
    taint {
      key    = "CriticalAddonsOnly"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    # Disable legacy instance metadata API (prevents credential theft via SSRF)
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }
}

# ==============================================================================
# Application Node Pool
# Auto-scaling pool for user workloads.
# Uses Spot/Preemptible VMs in dev for cost savings.
# Uses standard VMs in prod for reliability.
# ==============================================================================

resource "google_container_node_pool" "application" {
  name     = "${local.cluster_name}-app"
  project  = var.project_id
  location = var.location
  cluster  = google_container_cluster.primary.name

  # Cluster Autoscaler: scales node count based on pending pod requests
  autoscaling {
    min_node_count  = var.app_min_node_count
    max_node_count  = var.app_max_node_count
    location_policy = "BALANCED" # Spread nodes across zones evenly
  }

  node_config {
    machine_type    = var.app_machine_type
    disk_size_gb    = var.app_disk_size_gb
    disk_type       = "pd-ssd"
    image_type      = "COS_CONTAINERD"
    service_account = var.node_service_account_email

    # Spot VMs: ~60-90% cheaper, can be preempted. Use in dev/non-critical prod.
    spot = var.use_spot_instances

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = merge(var.node_labels, {
      "environment" = var.environment
      "node-pool"   = "application"
      "managed-by"  = "terraform"
    })

    metadata = {
      disable-legacy-endpoints = "true"
    }

    resource_labels = {
      environment = var.environment
      team        = "platform"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Surge upgrade: add new nodes before removing old ones → zero downtime
  upgrade_settings {
    max_surge       = 2
    max_unavailable = 0
    strategy        = "SURGE"
  }

  lifecycle {
    # Autoscaler manages node_count; ignore drift
    ignore_changes = [node_count]
  }
}
