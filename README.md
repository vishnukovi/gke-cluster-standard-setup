# GKE Standard Setup — Terraform

Production-grade Google Kubernetes Engine clusters for dev and prod environments, built with Terraform. Designed for product companies that need a secure, scalable, observable Kubernetes platform from day one.

---

## Architecture

```
environments/
├── dev/    ← Zonal cluster, Spot VMs, RAPID channel, open API access
└── prod/   ← Regional cluster (HA), standard VMs, REGULAR channel, locked-down

Each environment provisions:

  VPC ──────────────────────────────────────────────────────────────────────
  │  Private subnet (nodes)
  │  Secondary range: pods
  │  Secondary range: services
  │  Cloud NAT → internet (image pulls, package updates)
  │  Firewall rules (least-privilege)
  └──────────────────────────────────────────────────────────────────────────

  GKE Cluster (private nodes, VPC-native, Dataplane V2)
  ├── System node pool   [CriticalAddonsOnly taint]   fixed size
  └── App node pool      [Cluster Autoscaler]          auto-scaling

  IAM
  └── Dedicated node SA (log/metric writer, AR reader — no project editor!)
```

### Dev vs Prod — key differences

| Feature | Dev | Prod |
|---|---|---|
| Cluster type | Zonal (single zone) | Regional (3 zones, HA) |
| Spot VMs | ✅ (60-90% cheaper) | ❌ (no preemption risk) |
| Release channel | RAPID | REGULAR |
| Binary Authorization | Disabled | Enabled |
| Control plane access | Open (0.0.0.0/0) | Restricted to known CIDRs |
| App node min/max | 1–3 | 2–10 per zone |
| Machine types | e2-standard-{2,4} | n2-standard-{2,4} |
| Maintenance window | Any time | Weekends 02:00-06:00 UTC |

---

## Best Practices Implemented

### Security
- **Private nodes** — GKE nodes have no external IP addresses
- **Workload Identity** — no service account key files; K8s SAs authenticate directly as GCP SAs
- **Least-privilege node SA** — custom SA with only the 5 roles GKE actually needs (vs default Compute Editor)
- **Shielded nodes** — Secure Boot + Integrity Monitoring against rootkits/bootkits
- **Dataplane V2 (eBPF)** — built-in NetworkPolicy enforcement, no Calico install needed
- **Binary Authorization** (prod) — only signed, attested images can run
- **Disable legacy metadata API** — blocks SSRF-based credential theft on nodes
- **GKE Metadata Server** — workloads get short-lived tokens, not node SA credentials

### Reliability
- **Regional cluster** (prod) — control plane and nodes span 3 zones; survives a full zone failure
- **Cluster Autoscaler** — automatically adds/removes nodes based on pending pod requests
- **Surge upgrades** — new nodes added before old ones drained; zero downtime node pool updates
- **Vertical Pod Autoscaler** — automatically right-sizes CPU/memory requests over time
- **System node pool** — cluster-critical add-ons isolated from user workloads via taint
- **Auto-repair + auto-upgrade** — GKE heals unhealthy nodes and applies patches automatically

### Observability
- **Cloud Logging** — system components + workload logs shipped to Cloud Logging
- **Managed Prometheus (GMP)** — drop-in Prometheus without self-hosting the stack
- **NodeLocal DNSCache** — per-node DNS caching reduces latency and kube-dns load
- **VPC Flow Logs** — full network visibility for incident response

### Cost
- **Spot VMs** (dev) — saves 60-90% on node compute; acceptable for non-critical workloads
- **e2 machine types** (dev) — cost-optimized instances for development
- **Cluster Autoscaler** — nodes scale to zero when idle (within min_node_count bounds)
- **Zonal cluster** (dev) — avoids multi-zone control plane SLA cost

### Operations
- **GCS remote state** with versioning and lifecycle policy
- **Release channels** — Google manages the K8s version lifecycle
- **Maintenance windows** — upgrades only during defined low-traffic periods
- **Workload Identity Federation** in CI/CD — no long-lived SA keys stored as secrets

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Terraform | >= 1.5 | [developer.hashicorp.com/terraform](https://developer.hashicorp.com/terraform/install) |
| gcloud CLI | latest | [cloud.google.com/sdk](https://cloud.google.com/sdk/docs/install) |
| kubectl | latest | `gcloud components install kubectl` |
| gh (GitHub CLI) | latest | [cli.github.com](https://cli.github.com/) |

### GCP APIs that must be enabled

The setup script enables these automatically. Manual equivalent:

```bash
gcloud services enable \
  container.googleapis.com \
  compute.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  artifactregistry.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  dns.googleapis.com \
  binaryauthorization.googleapis.com \
  --project=YOUR_PROJECT_ID
```

---

## Project Structure

```
.
├── modules/
│   ├── vpc/            # VPC, subnet, Cloud NAT, firewall rules
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── gke/            # GKE cluster + system and app node pools
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── iam/            # Node service account with least-privilege roles
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   ├── dev/
│   │   ├── backend.tf          # GCS remote state (dev prefix)
│   │   ├── main.tf             # Module wiring + dev-specific config
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars    # Dev variable values (edit this)
│   └── prod/
│       ├── backend.tf          # GCS remote state (prod prefix)
│       ├── main.tf             # Module wiring + prod-specific config
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars    # Prod variable values (edit this)
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml  # PR: fmt check, validate, plan, post comment
│       └── terraform-apply.yml # Merge: apply dev (auto) → apply prod (manual approval)
├── scripts/
│   ├── setup.sh    # Bootstrap: APIs, GCS bucket, SA, WIF, terraform init
│   └── destroy.sh  # Safe teardown with confirmation prompt
├── .gitignore
├── .terraform-version
└── README.md
```

---

## Quick Start

### Step 1 — Clone and configure

```bash
git clone https://github.com/YOUR_ORG/YOUR_REPO.git
cd YOUR_REPO

# Edit dev values
vim environments/dev/terraform.tfvars

# Edit prod values
vim environments/prod/terraform.tfvars
```

### Step 2 — Bootstrap (first-time only)

The setup script enables APIs, creates the GCS state bucket, creates a CI/CD service account, and configures Workload Identity Federation for GitHub Actions.

```bash
# Set your GitHub repo for WIF attribute condition
export GITHUB_REPO="your-org/your-repo"

chmod +x scripts/setup.sh
./scripts/setup.sh dev your-gcp-project-id
```

### Step 3 — Deploy dev

```bash
cd environments/dev

# Replace YOUR_PROJECT_ID in backend.tf first
terraform init

terraform plan -var="project_id=your-gcp-project-id"
terraform apply -var="project_id=your-gcp-project-id"
```

### Step 4 — Connect kubectl

```bash
# The exact command is also printed as a Terraform output
gcloud container clusters get-credentials dev-gke-cluster \
  --zone us-central1-a \
  --project your-gcp-project-id

kubectl get nodes
```

### Step 5 — Deploy prod

```bash
cd environments/prod

terraform init
terraform plan  -var="project_id=your-gcp-project-id"
terraform apply -var="project_id=your-gcp-project-id"
```

---

## CI/CD Setup

### GitHub Actions — Workload Identity Federation

No SA keys stored in GitHub. The pipelines authenticate via short-lived OIDC tokens.

After running `setup.sh`, copy the printed values into your GitHub repo:

**Settings → Secrets and variables → Actions:**

| Name | Type | Value |
|---|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Secret | `projects/PROJECT_NUM/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `GCP_SERVICE_ACCOUNT` | Secret | `terraform-cicd@YOUR_PROJECT.iam.gserviceaccount.com` |
| `GCP_PROJECT_ID` | Variable | `your-gcp-project-id` |

### GitHub Environments

Create two GitHub Environments (**Settings → Environments**):

- `development` — no approval required (auto-deploy)
- `production` — add required reviewers (manual gate before prod apply)

### Pipeline behaviour

```
Pull Request opened/updated
  └── terraform-plan.yml
        ├── Detect changed environment (dev/prod)
        ├── terraform fmt + validate + plan
        └── Post plan diff as PR comment

Merge to main
  └── terraform-apply.yml
        ├── Apply dev   ← automatic
        └── Apply prod  ← waits for GitHub Environment approval
```

---

## Workload Identity for Applications

To give a workload access to GCP APIs without key files:

```bash
# 1. Create a GCP service account for the app
gcloud iam service-accounts create my-app-sa \
  --project=YOUR_PROJECT_ID

# 2. Grant it the required role (e.g., Cloud Storage access)
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --role=roles/storage.objectViewer \
  --member="serviceAccount:my-app-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com"

# 3. Bind the K8s ServiceAccount to the GCP SA
gcloud iam service-accounts add-iam-policy-binding \
  my-app-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:YOUR_PROJECT_ID.svc.id.goog[my-namespace/my-ksa]"

# 4. Annotate the K8s ServiceAccount
kubectl annotate serviceaccount my-ksa \
  --namespace my-namespace \
  iam.gke.io/gcp-service-account=my-app-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

---

## CIDR Planning

Use non-overlapping ranges if you plan to peer VPCs or connect via VPN.

| Range | Dev | Prod |
|---|---|---|
| Node subnet | `10.0.0.0/20` (4,096 IPs) | `10.10.0.0/20` |
| Pods | `10.1.0.0/16` (65,536 IPs) | `10.11.0.0/16` |
| Services | `10.2.0.0/20` (4,096 IPs) | `10.12.0.0/20` |
| Control plane | `172.16.0.0/28` | `172.16.1.0/28` |

> **Pod IP math**: GKE reserves 256 IPs per node (with `max_pods_per_node=110`). A `/16` supports ~256 nodes. Scale the pods CIDR if you need more nodes.

---

## Troubleshooting

**`Error: googleapi: Error 409: Already exists`**
The resource already exists outside Terraform state. Import it:
```bash
terraform import module.gke.google_container_cluster.primary projects/PROJECT/locations/LOCATION/clusters/NAME
```

**Nodes stuck in `NotReady`**
Check node logs and NAT gateway — private nodes need Cloud NAT to pull images:
```bash
kubectl describe node NODE_NAME
gcloud logging read 'resource.type="gce_instance"' --project=PROJECT_ID --limit=50
```

**`Error: Forbidden — Request had insufficient authentication scopes`**
The CI/CD SA is missing a required role. Check `scripts/setup.sh` for the full role list.

**`terraform init` fails with backend bucket error**
Create the GCS bucket first — see Step 2 (Bootstrap) above.

**Binary Authorization blocks image pulls (prod)**
Your image lacks a valid attestation. Either add an attestation or temporarily set `enable_binary_authorization = false` during initial rollout.

---

## Security Checklist

Before going to production:

- [ ] Replace `0.0.0.0/0` in `master_authorized_networks` with real CIDRs (VPN, bastion, CI/CD IPs)
- [ ] Enable Binary Authorization and configure an attestor policy
- [ ] Review IAM bindings — no `roles/owner` or `roles/editor` on service accounts
- [ ] Set up Cloud Armor on any public-facing Ingress/LoadBalancer
- [ ] Enable GKE Security Posture scanning
- [ ] Configure PodDisruptionBudgets for all stateful workloads
- [ ] Set resource `requests` and `limits` on all pods
- [ ] Configure NetworkPolicies to restrict pod-to-pod traffic
- [ ] Enable audit logging for the Kubernetes API server
- [ ] Rotate any manually created service account keys

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

MIT
