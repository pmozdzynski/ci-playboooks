# Complete Setup Guide: GitHub + GitLab CI/CD

This guide walks you through the complete setup for using GitHub as your source repository with GitLab CE for CI/CD orchestration.

## Architecture Overview

- **GitHub**: Source of truth (developers push/pull here)
- **GitLab CE**: CI/CD orchestration only (minimal storage)
- **GitLab Runners**: Execute jobs, clone from GitHub when needed

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed architecture.

## Prerequisites

- [ ] Self-hosted GitLab CE instance running
- [ ] GitHub repository with your code
- [ ] Network access from GitLab runners to GitHub
- [ ] Admin access to both GitHub and GitLab

## Step-by-Step Setup

### Step 1: Prepare GitHub Repository

1. **Ensure `.gitlab-ci.yml` is in your GitHub repository:**
   ```bash
   cd /path/to/your/github/repo
   # Copy .gitlab-ci.yml from ci-playboooks if not already there
   cp ci-playboooks/.gitlab-ci.yml .
   git add .gitlab-ci.yml
   git commit -m "Add GitLab CI configuration"
   git push
   ```

2. **Add GitHub Actions workflow** (optional but recommended):
   - The workflow in `.github/workflows/trigger-gitlab.yml` will automatically trigger GitLab pipelines
   - See Step 3 for configuration

### Step 2: Create GitLab Project

1. **Create a minimal project in GitLab:**
   - Go to GitLab → New Project → Create blank project
   - Name: `vmware` (or your project name)
   - Visibility: Private (recommended)
   - **Do NOT initialize with README**

2. **Note your project details:**
   - Project ID: Found in project settings → General
   - Project URL: `https://gitlab.example.com/group/vmware`

### Step 3: Configure GitLab Pipeline Trigger

1. **Create a pipeline trigger token:**
   - In GitLab: Settings → CI/CD → Pipeline triggers → Expand
   - Description: `GitHub Webhook Trigger`
   - Click "Add trigger"
   - **Copy the trigger token** (save it securely)

2. **Get the trigger URL:**
   - Format: `https://gitlab.example.com/api/v4/projects/PROJECT_ID/trigger/pipeline`
   - Or use: `https://gitlab.example.com/api/v4/projects/PROJECT_ID/ref/REF_NAME/trigger/pipeline`

### Step 4: Configure GitHub Secrets

1. **Add GitLab secrets to GitHub:**
   - Go to GitHub repository → Settings → Secrets and variables → Actions
   - Click "New repository secret"

2. **Add these secrets:**
   - **Name**: `GITLAB_TRIGGER_TOKEN`
     - **Value**: The trigger token from Step 3
   
   - **Name**: `GITLAB_API_URL`
     - **Value**: `https://gitlab.example.com/api/v4/projects/PROJECT_ID`
     - Replace `PROJECT_ID` with your GitLab project ID

3. **Verify secrets are added:**
   - You should see both secrets listed

### Step 5: Configure GitLab CI/CD Variables

1. **In GitLab, go to:**
   - Settings → CI/CD → Variables → Expand

2. **Add required variables:**
   - `ANSIBLE_SSH_KEY_FILE` (Type: **File**, Protected: ✅)
   - `ANSIBLE_VAULT_PASSWORD_FILE` (Type: **File**, Protected: ✅, Masked: ✅)
   - `VCENTER_PASSWORD` (Protected: ✅, Masked: ✅)
   - `GITHUB_REPO_URL` (Optional: `https://github.com/YOUR_USERNAME/YOUR_REPO.git`)

3. **Add optional variables:**
   - `INVENTORY_PATH`: `/opt/jenkins/inventories/fse/fse-internal`
   - `LIMIT_HOSTGROUP`: `fse_gibraltar`
   - `USE_VCENTER`: `true`
   - `VCENTER_USERNAME`: `administrator@vsphere.local`

### Step 6: Set Up GitLab Runner

1. **Install GitLab Runner** (if not already installed):
   ```bash
   sudo ./ci-playboooks/gitlab-runner-setup.sh
   ```

2. **Register the runner:**
   ```bash
   sudo gitlab-runner register
   ```
   - GitLab URL: `https://gitlab.example.com/`
   - Registration token: From GitLab → Settings → CI/CD → Runners
   - Description: `ansible-playbooks-runner`
   - Tags: `fse-gibraltar` (must match `.gitlab-ci.yml`)
   - Executor: `shell` (recommended for Ansible)

3. **Configure runner for GitHub access:**
   - Ensure runner can access GitHub:
     ```bash
     # Test connectivity
     ping github.com
     git ls-remote https://github.com/YOUR_USERNAME/YOUR_REPO.git
     ```

4. **Set up inventory and secrets** (if not using GitLab variables):
   ```bash
   # Copy inventory
   sudo cp -r /path/to/fse-internal /opt/jenkins/inventories/fse/
   sudo chown -R gitlab-runner:gitlab-runner /opt/jenkins/inventories/fse/fse-internal
   
   # If using filesystem secrets (not recommended, use GitLab variables instead)
   # sudo cp /path/to/ansible.key /opt/jenkins/secrets/
   # sudo chmod 600 /opt/jenkins/secrets/ansible.key
   # sudo chown gitlab-runner:gitlab-runner /opt/jenkins/secrets/ansible.key
   ```

### Step 7: Test the Integration

1. **Make a test commit in GitHub:**
   ```bash
   echo "test" >> test.txt
   git add test.txt
   git commit -m "Test GitLab CI trigger"
   git push
   ```

2. **Check GitHub Actions:**
   - Go to GitHub → Actions tab
   - You should see "Trigger GitLab CI/CD" workflow running
   - Check if it completed successfully

3. **Check GitLab Pipelines:**
   - Go to GitLab → CI/CD → Pipelines
   - You should see a new pipeline triggered
   - Check the pipeline status

4. **Verify pipeline execution:**
   - Click on the pipeline to see job details
   - Check job logs to verify execution
   - Verify Ansible playbooks are running correctly

### Step 8: Configure Branch Protection (Optional)

1. **In GitLab:**
   - Settings → Repository → Protected branches
   - Protect `master` and `main` branches
   - This ensures only authorized users can trigger production pipelines

2. **In GitHub:**
   - Settings → Branches → Add rule
   - Protect `master` and `main` branches
   - Require pull request reviews

## Alternative: Using GitLab Mirror Instead of Webhooks

If you prefer to have GitLab mirror the repository (still using GitHub as source):

1. **In GitLab project:**
   - Settings → Repository → Mirroring repositories
   - Add pull mirror:
     - **Git repository URL**: `https://github.com/YOUR_USERNAME/YOUR_REPO.git`
     - **Mirror direction**: Pull
     - **Trigger**: Every push
   - Save

2. **Use GitLab webhooks or manual triggers:**
   - Pipelines can be triggered manually or via GitLab webhooks
   - Runners clone from GitLab (which is synced from GitHub)

## Troubleshooting

### Pipeline Not Triggering

1. **Check GitHub Actions logs:**
   - Go to Actions tab → Click on the workflow run
   - Check for error messages

2. **Verify secrets:**
   - Ensure `GITLAB_TRIGGER_TOKEN` and `GITLAB_API_URL` are set correctly
   - Check if secrets are accessible to the workflow

3. **Check GitLab trigger token:**
   - Verify the token is still valid in GitLab
   - Check if the token has the correct permissions

### Runner Not Picking Up Jobs

1. **Check runner status:**
   ```bash
   sudo gitlab-runner status
   sudo gitlab-runner verify
   ```

2. **Check runner tags:**
   - Ensure runner tags match `.gitlab-ci.yml` (should be `fse-gibraltar`)

3. **Check runner logs:**
   ```bash
   sudo gitlab-runner --debug run
   ```

### Cannot Clone from GitHub

1. **Test network connectivity:**
   ```bash
   ping github.com
   git ls-remote https://github.com/YOUR_USERNAME/YOUR_REPO.git
   ```

2. **Check if repository is private:**
   - If private, ensure runner has access
   - Use deploy keys or personal access tokens

3. **Verify GitLab project configuration:**
   - If using mirror, check mirror status in GitLab

## Security Checklist

- [ ] GitLab trigger token is strong and unique
- [ ] GitHub secrets are properly configured
- [ ] GitLab CI/CD variables are protected and masked where appropriate
- [ ] Runners have minimal required permissions
- [ ] Branch protection is enabled
- [ ] Webhook deliveries are monitored
- [ ] Audit logs are reviewed regularly

## Next Steps

- Review [ARCHITECTURE.md](./ARCHITECTURE.md) for architecture details
- See [GITHUB_WEBHOOK_SETUP.md](./GITHUB_WEBHOOK_SETUP.md) for webhook configuration
- See [GITLAB_CI_SETUP.md](./GITLAB_CI_SETUP.md) for detailed GitLab setup
- See [SECURITY.md](./SECURITY.md) for security best practices

## Estimated Setup Time

- GitLab project setup: 15 minutes
- GitHub secrets configuration: 10 minutes
- GitLab CI/CD variables: 15 minutes
- Runner setup: 30-60 minutes
- Testing and troubleshooting: 30-60 minutes

**Total: ~2-3 hours** (depending on runner complexity)

