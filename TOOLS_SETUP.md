# Tools Setup Guide for CI/CD Pipelines

This guide explains how to set up the required tools (Ansible, Terraform, kapp) on GitLab runners for the CI/CD pipelines.

## Overview

The CI/CD pipelines support three main infrastructure automation tools:

1. **Ansible** - Configuration management and system provisioning
2. **Terraform** - Infrastructure as Code (IaC)
3. **kapp** (Carvel) - Kubernetes application deployment

## Prerequisites

- GitLab Runner installed and registered
- Root or sudo access on runner host
- Network connectivity to download tools

## Ansible Setup

### Installation

#### On Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install -y ansible python3-pip python3-venv

# Install Python dependencies for VMware
sudo pip3 install pyvmomi requests

# Install Ansible VMware collection
ansible-galaxy collection install vmware.vmware_rest
```

#### On RHEL/CentOS:
```bash
sudo yum install -y epel-release
sudo yum install -y ansible python3-pip

# Install Python dependencies
sudo pip3 install pyvmomi requests

# Install Ansible VMware collection
ansible-galaxy collection install vmware.vmware_rest
```

### Verification

```bash
ansible --version
ansible-galaxy --version
python3 -c "import pyvmomi; print('pyvmomi installed')"
```

### Configuration

- Ansible configuration: `ansible.cfg` in project root
- Inventory files: Configured via `INVENTORY_PATH` CI/CD variable
- SSH keys: Stored in GitLab CI/CD variables (`ANSIBLE_SSH_KEY_FILE`)

## Terraform Setup

### Installation

#### Download and Install:
```bash
# Set version (check latest at https://www.terraform.io/downloads)
TERRAFORM_VERSION="1.6.0"

# Download
cd /tmp
wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Install
sudo unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin/
sudo chmod +x /usr/local/bin/terraform
rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
```

#### Using Package Manager (if available):
```bash
# Ubuntu/Debian
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# RHEL/CentOS
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum install -y terraform
```

### Verification

```bash
terraform --version
terraform init  # Test in a terraform directory
```

### Configuration

- **Backend Configuration**: Store in `backend.hcl` or set via `TF_BACKEND_CONFIG` variable
- **Infrastructure Provider Credentials**: Store in GitLab CI/CD variables:
  - vCenter credentials (for VMware provider)
  - Storage system credentials (for storage provisioning)
  - Network device credentials (for network automation)
  - Other on-premises infrastructure provider credentials
- **State Management**: Use remote backends (on-premises storage, GitLab, or local filesystem)

### Example Backend Configuration

```hcl
# backend.hcl - On-premises storage example
terraform {
  backend "local" {
    path = "/opt/terraform/state/terraform.tfstate"
  }
}

# Or use GitLab as backend (if using GitLab Premium)
# terraform {
#   backend "http" {
#     address = "https://gitlab.example.com/api/v4/projects/PROJECT_ID/terraform/state/default"
#     lock_address = "https://gitlab.example.com/api/v4/projects/PROJECT_ID/terraform/state/default/lock"
#     unlock_address = "https://gitlab.example.com/api/v4/projects/PROJECT_ID/terraform/state/default/lock"
#   }
# }
```

## kapp (Carvel) Setup

### Installation

kapp is part of the Carvel tool suite. Install using one of these methods:

#### Method 1: Download Binary
```bash
# Set version (check latest at https://github.com/vmware-tanzu/carvel-kapp/releases)
KAPP_VERSION="0.61.0"

# Download
cd /tmp
wget https://github.com/vmware-tanzu/carvel-kapp/releases/download/v${KAPP_VERSION}/kapp-linux-amd64

# Install
sudo mv kapp-linux-amd64 /usr/local/bin/kapp
sudo chmod +x /usr/local/bin/kapp
```

#### Method 2: Using Carvel Package Manager
```bash
# Install Carvel tools (includes kapp)
curl -fsSL https://carvel.dev/install.sh | bash

# Or install just kapp
sudo install -m 0755 -d /usr/local/bin
sudo install -m 0755 /tmp/carvel/kapp /usr/local/bin/kapp
```

### Verification

```bash
kapp version
```

### Prerequisites

kapp requires kubectl and access to a Kubernetes cluster:

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

### Configuration

- **Kubeconfig**: Store in GitLab CI/CD variable `KUBECONFIG_FILE` (File type)
- **Application Name**: Set via `KAPP_APP_NAME` CI/CD variable
- **Configuration Files**: Place in `kapp/` directory or use `kapp.yml`

### Example kapp Configuration

```yaml
# kapp.yml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: my-app:latest
        ports:
        - containerPort: 8080
```

## Automated Setup Script

Create a setup script to install all tools:

```bash
#!/bin/bash
# setup-ci-tools.sh

set -e

echo "Installing CI/CD tools..."

# Install Ansible
if ! command -v ansible &> /dev/null; then
    echo "Installing Ansible..."
    # Add your Ansible installation commands here
fi

# Install Terraform
if ! command -v terraform &> /dev/null; then
    echo "Installing Terraform..."
    TERRAFORM_VERSION="1.6.0"
    wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    sudo unzip -q terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin/
    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
fi

# Install kapp
if ! command -v kapp &> /dev/null; then
    echo "Installing kapp..."
    KAPP_VERSION="0.61.0"
    wget -q https://github.com/vmware-tanzu/carvel-kapp/releases/download/v${KAPP_VERSION}/kapp-linux-amd64
    sudo mv kapp-linux-amd64 /usr/local/bin/kapp
    sudo chmod +x /usr/local/bin/kapp
fi

# Install kubectl
if ! command -v kubectl &> /dev/null; then
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

# Verify installations
echo "Verifying installations..."
ansible --version
terraform --version
kapp version
kubectl version --client

echo "All tools installed successfully!"
```

## GitLab CI/CD Variables

Configure these variables in GitLab (Settings → CI/CD → Variables):

### Ansible Variables
- `ANSIBLE_SSH_KEY_FILE` (File type, Protected)
- `ANSIBLE_VAULT_PASSWORD_FILE` (File type, Protected, Masked)
- `INVENTORY_PATH` (default: `/opt/jenkins/inventories/fse/fse-internal`)

### Terraform Variables
- `TF_BACKEND_CONFIG` (path to backend.hcl)
- `VCENTER_USERNAME` (Protected)
- `VCENTER_PASSWORD` (Protected, Masked)
- `VCENTER_SERVER` (vCenter hostname/IP)
- Infrastructure provider credentials (storage, networking, etc.)

### kapp Variables
- `KUBECONFIG_FILE` (File type, Protected)
- `KAPP_APP_NAME` (default: `app`)

## Testing Tools

### Test Ansible
```bash
ansible --version
ansible-playbook --syntax-check playbooks/systembase.yml
```

### Test Terraform
```bash
terraform --version
cd terraform/
terraform init
terraform validate
terraform plan
```

### Test kapp
```bash
kapp version
kubectl cluster-info
kapp list -A
```

## Troubleshooting

### Ansible Issues
- **Missing modules**: Install via `ansible-galaxy` or `pip`
- **SSH connection**: Verify SSH keys and permissions
- **VMware connection**: Check pyvmomi installation and credentials

### Terraform Issues
- **Backend errors**: Verify backend configuration and credentials
- **Provider errors**: Check infrastructure provider credentials (vCenter, storage, networking)
- **State lock**: Check for concurrent runs or stale locks

### kapp Issues
- **Kubernetes connection**: Verify kubeconfig and cluster access
- **Resource conflicts**: Check for existing resources with same name
- **Deployment failures**: Review kapp logs and Kubernetes events

## Maintenance

### Updating Tools

- **Ansible**: `pip3 install --upgrade ansible`
- **Terraform**: Download new version and replace binary
- **kapp**: Download new version and replace binary
- **kubectl**: Download new version and replace binary

### Version Pinning

Consider pinning tool versions in your CI/CD pipeline:

```yaml
before_script:
  - terraform --version | grep "Terraform v1.6.0"
  - kapp version | grep "kapp version 0.61.0"
```

## Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [kapp Documentation](https://carvel.dev/kapp/)
- [Carvel Tools](https://carvel.dev/)

