# GitLab CI/CD Setup Guide

This guide explains how to set up GitLab CI/CD for the Ansible playbooks repository, including repository mirroring from GitHub and GitLab runner configuration.

## Table of Contents

1. [Repository Mirroring (GitHub → GitLab)](#repository-mirroring)
2. [GitLab Runner Setup](#gitlab-runner-setup)
3. [GitLab CI/CD Variables Configuration](#gitlab-cicd-variables)
4. [Pipeline Usage](#pipeline-usage)

## Repository Mirroring

Since your code is in GitHub but you want to use GitLab CI/CD, you have two options:

### Option 1: Push Mirror (Recommended)

Set up a push mirror in GitLab to automatically sync from GitHub:

1. **In GitLab:**
   - Go to your project → Settings → Repository → Mirroring repositories
   - Add a new push mirror:
     - **Git repository URL**: `https://github.com/YOUR_USERNAME/YOUR_REPO.git`
     - **Mirror direction**: Push
     - **Authentication method**: Password or Personal Access Token
     - **Trigger**: Push events
   - Save the mirror

2. **In GitHub:**
   - Create a Personal Access Token (Settings → Developer settings → Personal access tokens)
   - Grant `repo` permissions
   - Use this token in GitLab mirror configuration

### Option 2: Manual Mirroring Script

Create a webhook or scheduled job to sync repositories:

```bash
#!/bin/bash
# sync-to-gitlab.sh

GITHUB_REPO="git@github.com:YOUR_USERNAME/YOUR_REPO.git"
GITLAB_REPO="git@gitlab.com:YOUR_GROUP/YOUR_REPO.git"

# Fetch from GitHub
git fetch origin

# Push to GitLab
git push --mirror "$GITLAB_REPO"
```

### Option 3: GitHub Actions to GitLab

Use GitHub Actions to automatically push to GitLab on every push:

```yaml
# .github/workflows/mirror-to-gitlab.yml
name: Mirror to GitLab

on:
  push:
    branches: [ master, main, develop ]

jobs:
  mirror:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - name: Mirror to GitLab
        run: |
          git remote add gitlab https://gitlab.com/YOUR_GROUP/YOUR_REPO.git
          git push gitlab --mirror
        env:
          GITLAB_TOKEN: ${{ secrets.GITLAB_TOKEN }}
```

## GitLab Runner Setup

### Prerequisites

The GitLab runner needs:
- Ansible installed
- Python 3 with required packages (pyvmomi for VMware modules)
- SSH access to target hosts
- Access to inventory files and secrets

### Installing GitLab Runner

1. **Install GitLab Runner** (on the machine that will run playbooks):

```bash
# For Linux
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner

# Or for RHEL/CentOS
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
sudo yum install gitlab-runner
```

2. **Register the Runner:**

```bash
sudo gitlab-runner register
```

You'll need:
- **GitLab URL**: `https://gitlab.com/` (or your GitLab instance)
- **Registration token**: Found in GitLab project → Settings → CI/CD → Runners → Expand "Set up a specific runner manually"
- **Description**: e.g., "Ansible Playbooks Runner"
- **Tags**: `fse-gibraltar` (or your preferred tag)
- **Executor**: `shell` (recommended for Ansible) or `docker`

### Runner Configuration

Edit `/etc/gitlab-runner/config.toml`:

```toml
[[runners]]
  name = "fse-gibraltar-runner"
  url = "https://gitlab.com/"
  token = "YOUR_RUNNER_TOKEN"
  executor = "shell"
  shell = "bash"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
```

### Installing Dependencies on Runner

```bash
# Install Ansible
sudo apt-get update
sudo apt-get install -y ansible python3-pip

# Install Python dependencies for VMware
sudo pip3 install pyvmomi

# Install Ansible VMware collection (optional but recommended)
ansible-galaxy collection install vmware.vmware_rest

# Create directories for inventory and secrets
sudo mkdir -p /opt/jenkins/inventories/fse
sudo mkdir -p /opt/jenkins/secrets

# Set proper permissions
sudo chown -R gitlab-runner:gitlab-runner /opt/jenkins/inventories
sudo chown -R gitlab-runner:gitlab-runner /opt/jenkins/secrets
```

### Setting Up Inventory

Copy your inventory files to the runner:

```bash
# Copy inventory directory
sudo cp -r /path/to/fse-internal /opt/jenkins/inventories/fse/

# Set ownership
sudo chown -R gitlab-runner:gitlab-runner /opt/jenkins/inventories/fse/fse-internal
```

### Setting Up Secrets

**Important:** Store secrets securely. The pipeline supports multiple methods, with GitLab CI/CD variables being the most secure.

#### Option 1: GitLab File Variables (Recommended for SSH Keys) ⭐

**Yes, it's safe to store SSH keys in GitLab!** GitLab File variables are the recommended method:

**Security Features:**
- ✅ Encrypted at rest in GitLab's database
- ✅ Automatically written to temporary files (no manual file management)
- ✅ Files are automatically cleaned up after jobs
- ✅ Can be protected (only available on protected branches/tags)
- ✅ Access controlled via GitLab permissions
- ✅ Audit trail in GitLab logs
- ✅ No need to manage files on runner filesystem

**Setup Steps:**

1. Go to Project → Settings → CI/CD → Variables → Expand
2. Click "Add variable"
3. For SSH Key:
   - **Key**: `ANSIBLE_SSH_KEY_FILE`
   - **Value**: Paste your SSH private key content (entire key including `-----BEGIN` and `-----END` lines)
   - **Type**: Select **"File"** (this is important!)
   - **Protected**: ✅ Check (only available on protected branches)
   - **Masked**: ❌ Don't check (SSH keys are too long to mask)
   - **Expand variable reference**: ✅ Check
4. For Vault Password:
   - **Key**: `ANSIBLE_VAULT_PASSWORD_FILE`
   - **Value**: Your vault password
   - **Type**: Select **"File"**
   - **Protected**: ✅ Check
   - **Masked**: ✅ Check (recommended for passwords)
   - **Expand variable reference**: ✅ Check

**How it works:**
- GitLab automatically writes the content to a temporary file
- The variable name (e.g., `ANSIBLE_SSH_KEY_FILE`) contains the file path
- The pipeline uses this file path automatically
- Files are cleaned up after the job completes

#### Option 2: GitLab Regular Variables (Alternative)

For smaller secrets like passwords, you can use regular variables:

1. Go to Project → Settings → CI/CD → Variables
2. Add variables:
   - `ANSIBLE_SSH_KEY`: SSH private key content (regular variable)
   - `ANSIBLE_VAULT_PASSWORD`: Vault password (masked, protected)
   - `VCENTER_PASSWORD`: vCenter password (masked, protected)

**Note:** The pipeline will automatically write these to temporary files with proper permissions.

#### Option 3: Files on Runner Filesystem (Legacy)

If you prefer to keep secrets on the runner filesystem:

```bash
# Copy Ansible private key
sudo cp /path/to/ansible.key /opt/jenkins/secrets/
sudo chmod 600 /opt/jenkins/secrets/ansible.key
sudo chown gitlab-runner:gitlab-runner /opt/jenkins/secrets/ansible.key

# Create vault password file
echo "your-vault-password" | sudo tee /opt/jenkins/secrets/vault.txt
sudo chmod 600 /opt/jenkins/secrets/vault.txt
sudo chown gitlab-runner:gitlab-runner /opt/jenkins/secrets/vault.txt
```

**Security Considerations:**
- ⚠️ Files persist on the runner filesystem
- ⚠️ Requires manual file management
- ⚠️ Less centralized control
- ✅ Good for air-gapped environments

#### Option 4: HashiCorp Vault Integration (Advanced)

For enterprise environments with existing Vault infrastructure:
- Configure GitLab to use Vault for secrets
- Update pipeline to fetch secrets from Vault
- See [GitLab Vault Integration](https://docs.gitlab.com/ee/ci/secrets/#use-hashicorp-vault)

## GitLab CI/CD Variables

Configure these variables in GitLab (Settings → CI/CD → Variables):

### Required Variables (Secrets)

| Variable | Type | Description | Protected | Masked | Notes |
|----------|------|-------------|-----------|--------|-------|
| `ANSIBLE_SSH_KEY_FILE` | **File** ⭐ | SSH private key for Ansible | ✅ Yes | ❌ No | **Recommended** - GitLab File variable |
| `ANSIBLE_VAULT_PASSWORD_FILE` | **File** ⭐ | Ansible vault password | ✅ Yes | ✅ Yes | **Recommended** - GitLab File variable |
| `VCENTER_PASSWORD` | Variable | vCenter password | ✅ Yes | ✅ Yes | Can also use File type |

**Alternative Variable Names** (if not using File type):
- `ANSIBLE_SSH_KEY`: Regular variable with SSH key content
- `ANSIBLE_VAULT_PASSWORD`: Regular variable with vault password

### Optional Configuration Variables

| Variable | Description | Example | Protected | Masked |
|----------|-------------|---------|-----------|--------|
| `INVENTORY_PATH` | Path to Ansible inventory | `/opt/jenkins/inventories/fse/fse-internal` | No | No |
| `SECRETS_PATH` | Path to secrets directory (legacy) | `/opt/jenkins/secrets` | No | No |
| `LIMIT_HOSTGROUP` | Host group to limit execution | `fse_gibraltar` | No | No |
| `USE_VCENTER` | Enable vCenter integration | `true` | No | No |
| `VCENTER_USERNAME` | vCenter username | `administrator@vsphere.local` | Yes | No |
| `NEWINSTALL` | New installation flag | `true` | No | No |

### How the Pipeline Handles Secrets

The pipeline automatically detects and uses secrets in this priority order:

1. **GitLab File Variables** (highest priority):
   - `ANSIBLE_SSH_KEY_FILE` → automatically written to file by GitLab
   - `ANSIBLE_VAULT_PASSWORD_FILE` → automatically written to file by GitLab

2. **GitLab Regular Variables**:
   - `ANSIBLE_SSH_KEY` → written to temporary file by pipeline
   - `ANSIBLE_VAULT_PASSWORD` → written to temporary file by pipeline

3. **Runner Filesystem** (fallback):
   - `${SECRETS_PATH}/ansible.key`
   - `${SECRETS_PATH}/vault.txt`

All temporary files are automatically cleaned up after the job completes.

## Pipeline Usage

### Running Pipelines

1. **Automatic Validation:**
   - Runs on every push and merge request
   - Validates playbook syntax
   - Does not deploy anything

2. **Manual Deployment:**
   - Go to CI/CD → Pipelines
   - Click on a pipeline
   - Click the play button (▶) next to the job you want to run
   - Select variables if needed

### Customizing Deployments

You can override variables when running manual jobs:

- `LIMIT_HOSTGROUP`: Deploy to specific host group
- `USE_VCENTER`: Enable/disable vCenter integration
- `NEWINSTALL`: Set to `false` for updates

### Example: Deploy to Specific Host Group

1. Go to CI/CD → Pipelines
2. Click "Run pipeline"
3. Add variable: `LIMIT_HOSTGROUP` = `k8s_master`
4. Run the pipeline
5. Manually trigger `deploy_systembase` job

## Troubleshooting

### Runner Not Picking Up Jobs

- Check runner status: `sudo gitlab-runner status`
- Verify tags match in `.gitlab-ci.yml` and runner configuration
- Check runner logs: `sudo gitlab-runner --debug run`

### Ansible Connection Issues

- Verify SSH key permissions: `chmod 600 /opt/jenkins/secrets/ansible.key`
- Test SSH connection manually from runner
- Check inventory file paths

### Missing Roles

- Roles are installed automatically via `ansible-galaxy install`
- Check `roles/requirements.yml` for correct GitHub URLs
- Ensure runner has SSH access to GitHub (or use HTTPS with token)

### Permission Denied Errors

- Ensure `gitlab-runner` user has access to inventory and secrets
- Check file ownership: `sudo chown -R gitlab-runner:gitlab-runner /opt/jenkins/`

## Security Best Practices

1. **Never commit secrets** to the repository
2. **Use GitLab CI/CD variables** for sensitive data
3. **Restrict runner access** to necessary directories only
4. **Use protected branches** for production deployments
5. **Enable manual deployments** for production (already configured)
6. **Rotate secrets regularly**
7. **Use separate runners** for different environments

## Next Steps

1. Set up repository mirroring (choose one option above)
2. Install and register GitLab runner
3. Configure CI/CD variables in GitLab
4. Test the pipeline with a validation job
5. Run a manual deployment to verify everything works

