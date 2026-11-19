#!/bin/bash
set -euxo pipefail

# Install Docker & Git (intentionally do NOT run full 'dnf upgrade' so baseline host packages remain patchable in demo)
dnf install -y docker git python3-pip
systemctl enable --now docker
systemctl enable --now amazon-ssm-agent

# Clone the demo repo
mkdir -p /opt/demo-app
git clone "${github_repo_url}" /opt/demo-app

# Install vulnerable Python packages into a dedicated venv (avoids colliding with RPM-managed Python packages)
python3 -m venv /opt/demo-venv
/opt/demo-venv/bin/pip install --no-cache-dir -r /opt/demo-app/app/requirements.txt

cd /opt/demo-app/app
docker build -t zeroday-aitd-demo-app:v1 .
docker run -d \
  --name zeroday-demo-app \
  --restart unless-stopped \
  -p 8080:8080 \
  -e APP_ENV=sandbox \
  zeroday-aitd-demo-app:v1