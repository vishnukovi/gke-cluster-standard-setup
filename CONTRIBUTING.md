# Contributing

## Workflow

1. Create a branch from `main`
2. Make changes to modules or environments
3. Run `terraform fmt -recursive` before committing
4. Open a PR — the plan workflow will comment the diff
5. Get review and approval
6. Merge — dev auto-applies, prod waits for GitHub Environment approval

## Module changes

Changes to `modules/` affect **both** environments. Always:
- Plan both `environments/dev` and `environments/prod` before merging
- Test in dev before promoting to prod

## Coding conventions

- Use `snake_case` for all resource names and variables
- Every variable must have a `description`
- Every output must have a `description`
- Add validation blocks for variables that have a restricted set of valid values
- Keep environment-specific logic in `environments/`, not in `modules/`

## Running locally

```bash
cd environments/dev
terraform init
terraform fmt -recursive ../../
terraform validate
terraform plan -var="project_id=your-dev-project"
```
