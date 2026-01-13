# CI/CD Pipelines - Infrastructure Automation

This directory contains CI/CD pipeline configurations for automating infrastructure provisioning, configuration management, and application deployment using multiple tools, with GitLab CI/CD integration.

## Overview

The CI/CD pipelines support multiple infrastructure automation tools:

### Ansible
- VMware guest provisioning (VM creation from templates)
- Base VM configuration (networking, certificates, NFS, etc.)
- Docker installation and configuration
- Kubernetes cluster setup (masters and nodes)
- CNI (Container Network Interface) configuration

### Terraform
- Infrastructure as Code (IaC) for cloud resources
- Network infrastructure provisioning
- Resource lifecycle management
- State management and collaboration

### kapp (Carvel)
- Kubernetes application deployment
- Application lifecycle management
- Multi-resource application orchestration
- Change tracking and rollback capabilities

## Structure

```
ci-playboooks/
├── .gitlab-ci.yml          # GitLab CI/CD pipeline configuration
├── ansible.cfg             # Ansible configuration
├── playbooks/              # Ansible playbooks
│   ├── systembase.yml      # Base system provisioning
│   ├── systembase_bac.yaml # Alternative base system playbook
│   └── kubernetes_site.yaml # Kubernetes cluster setup
├── roles/                  # Ansible roles (installed via requirements.yml)
│   └── requirements.yml    # Role dependencies from GitHub
└── GITLAB_CI_SETUP.md      # Detailed setup guide

```

## Quick Start

### Prerequisites

**Common Requirements:**
- GitLab runner configured (see setup guide)
- Network access to target environments

**Ansible:**
- Ansible 2.9+
- Python 3 with `pyvmomi` package
- Access to vCenter/vSphere
- SSH access to target hosts

**Terraform:**
- Terraform latest stable version
- Infrastructure provider credentials (vCenter, storage systems, network devices)
- Terraform backend configuration (on-premises storage or local)

**kapp:**
- kapp (Carvel) latest version
- kubectl configured
- Kubernetes cluster access (kubeconfig)

### Running Playbooks Locally

1. **Install Ansible roles:**
   ```bash
   ansible-galaxy install -r roles/requirements.yml
   ```

2. **Run a playbook:**
   ```bash
   ansible-playbook playbooks/systembase.yml \
     -i /path/to/inventory \
     --private-key /path/to/ansible.key \
     --vault-password-file /path/to/vault.txt \
     -e limit_hostgroup=fse_gibraltar \
     -e use_vcenter=true \
     -e vcenter_username=administrator@vsphere.local \
     -e newinstall=true \
     -e vcenter_password=your_password
   ```

## GitLab CI/CD

This project is configured to run in GitLab CI/CD while the source code is maintained in GitHub.

**Architecture:** GitHub (source of truth) → GitLab CE (CI/CD orchestration only) → GitLab Runners (execute jobs)

This setup allows you to:
- Keep code in GitHub (no disruption to developer workflows)
- Use GitLab CE self-hosted only for CI/CD (minimal storage usage)
- Trigger pipelines via GitHub webhooks
- Full pipeline visibility in GitLab UI

See [ARCHITECTURE.md](./ARCHITECTURE.md) for architecture details and [SETUP_GITHUB_GITLAB.md](./SETUP_GITHUB_GITLAB.md) for complete setup instructions.

### Setup

See [GITLAB_CI_SETUP.md](./GITLAB_CI_SETUP.md) for detailed instructions on:
- Setting up repository mirroring (GitHub → GitLab)
- Installing and configuring GitLab runner
- Configuring CI/CD variables
- Running pipelines

### Pipeline Stages

1. **Validate**: Syntax checks and validation (runs automatically)
   - Ansible playbook syntax validation
   - Terraform plan (dry-run)
   - kapp configuration validation

2. **Deploy**: Manual deployment jobs for:
   - `deploy_systembase`: Base system provisioning (Ansible)
   - `deploy_systembase_bac`: Alternative base system playbook (Ansible)
   - `deploy_kubernetes`: Kubernetes cluster setup (Ansible)
   - `terraform_apply`: Infrastructure provisioning (Terraform)
   - `kapp_deploy`: Kubernetes application deployment (kapp)

### Quick Setup Commands

1. **Set up GitLab runner:**
   ```bash
   sudo ./gitlab-runner-setup.sh
   sudo gitlab-runner register
   ```

2. **Mirror repository to GitLab:**
   ```bash
   # Option 1: Use GitLab's push mirror feature (recommended)
   # Go to GitLab → Settings → Repository → Mirroring
   
   # Option 2: Use the mirror script
   export GITHUB_REPO="git@github.com:YOUR_USERNAME/YOUR_REPO.git"
   export GITLAB_REPO="git@gitlab.com:YOUR_GROUP/YOUR_REPO.git"
   ./mirror-to-gitlab.sh
   
   # Option 3: Use GitHub Actions (automated)
   # Configure secrets in GitHub and push to trigger
   ```

## Playbooks

### systembase.yml

Base system provisioning playbook that:
- Provisions VMs from vCenter templates (if `use_vcenter=true`)
- Configures base VM settings (networking, certificates, NFS, etc.)
- Only runs on new installations when `newinstall=true`

**Variables:**
- `limit_hostgroup`: Host group to target (required)
- `use_vcenter`: Enable vCenter integration (default: `true`)
- `vcenter_username`: vCenter username (default: `administrator@vsphere.local`)
- `vcenter_password`: vCenter password (required)
- `newinstall`: New installation flag (default: `true`)

### systembase_bac.yaml

Alternative playbook that includes Kubernetes setup in addition to base provisioning.

### kubernetes_site.yaml

Kubernetes cluster setup playbook that:
- Installs Docker on all nodes
- Configures Kubernetes masters
- Configures Kubernetes nodes
- Sets up CNI (Container Network Interface)
- Optionally installs Helm, MetalLB, and healthcheck tools

**Targets:**
- `kubernetz`: All Kubernetes hosts (Docker installation)
- `k8s_master`: Kubernetes master nodes
- `k8s_node`: Kubernetes worker nodes

## Roles

Roles are installed from GitHub repositories via `ansible-galaxy`:

- `vmware.guest`: VMware guest provisioning
- `base.vm`: Base VM configuration
- `configure.docker`: Docker installation
- `configure.kubernetes`: Kubernetes setup
- `configure.cni`: CNI configuration
- `commons`: Common utilities

See `roles/requirements.yml` for the complete list and versions.

## Inventory

The playbooks expect an Ansible inventory file. The default path in GitLab CI is:
```
/opt/jenkins/inventories/fse/fse-internal
```

You can override this via the `INVENTORY_PATH` CI/CD variable.

## Secrets Management

Secrets are managed via **GitLab CI/CD Variables** (recommended and secure):

### Recommended Setup (GitLab File Variables)

1. Go to **Project → Settings → CI/CD → Variables**
2. Add File variables:
   - `ANSIBLE_SSH_KEY_FILE` (Type: **File**, Protected: ✅)
   - `ANSIBLE_VAULT_PASSWORD_FILE` (Type: **File**, Protected: ✅, Masked: ✅)
   - `VCENTER_PASSWORD` (Protected: ✅, Masked: ✅)

**Why File Variables?**
- ✅ Encrypted at rest in GitLab
- ✅ Automatically cleaned up after jobs
- ✅ Proper file permissions handled automatically
- ✅ No secrets in job logs
- ✅ Centralized management with audit trail

### Alternative Methods

The pipeline also supports:
- Regular GitLab variables (automatically converted to files)
- Files on runner filesystem (legacy method)

See [SECURITY.md](./SECURITY.md) for detailed security information and [GITLAB_CI_SETUP.md](./GITLAB_CI_SETUP.md) for setup instructions.

**Important:** 
- ✅ **Yes, it's safe to store SSH keys in GitLab!** Use File variables.
- ❌ Never commit secrets to the repository!

## Troubleshooting

### Pipeline Issues

- **Runner not picking up jobs**: Check runner tags match `.gitlab-ci.yml`
- **Ansible connection errors**: Verify SSH key permissions and inventory paths
- **Missing roles**: Check `roles/requirements.yml` and GitHub access

### Playbook Issues

- **VM provisioning fails**: Check vCenter credentials and permissions
- **SSH connection fails**: Verify SSH key and network connectivity
- **Role errors**: Ensure all roles are installed via `ansible-galaxy install`

See [GITLAB_CI_SETUP.md](./GITLAB_CI_SETUP.md) for more troubleshooting tips.

## Contributing

1. Make changes in GitHub repository
2. Changes will be mirrored to GitLab (if mirroring is configured)
3. GitLab CI will validate playbooks automatically
4. Deploy manually via GitLab CI/CD pipeline

## Related Documentation

- [GITLAB_CI_SETUP.md](./GITLAB_CI_SETUP.md): Detailed GitLab CI/CD setup guide
- [Ansible Documentation](https://docs.ansible.com/)
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)

