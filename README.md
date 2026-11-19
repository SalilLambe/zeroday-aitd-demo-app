# Zero-Day AITD Demo App (AWS + Wiz + Google SecOps)

Sample vulnerable containerized application and AWS sandbox infrastructure for demonstrating end-to-end zero-day discovery, AI triage, HITL containment, OS/package patching, and SecOps integration.

## Deploy
1. Push this repo to GitHub (`main` branch).
2. `cd infra`
3. `terraform init && terraform apply`
4. Verify `curl http://<ec2_public_ip>:8080/inventory` returns `{"packages": ...}`.