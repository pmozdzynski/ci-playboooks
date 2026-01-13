# Complete Setup Guide: Bitbucket + GitLab CI/CD

This guide walks you through the complete setup for using Bitbucket Server/Data Center as your source repository with GitLab CE for CI/CD orchestration.

## Architecture Overview

- **Bitbucket Server/Data Center**: Source of truth (developers push/pull here)
- **GitLab CE**: CI/CD orchestration only (minimal storage)
- **GitLab Runners**: Execute jobs, clone from Bitbucket when needed

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed architecture.

## Prerequisites

- [ ] Self-hosted GitLab CE instance running
- [ ] Bitbucket Server/Data Center instance running
- [ ] Network access from GitLab runners to Bitbucket
- [ ] Admin access to both Bitbucket and GitLab
- [ ] Optional: Active Directory/LDAP for GitLab authentication

## Step-by-Step Setup

### Step 1: Prepare Bitbucket Repository

1. **Ensure `.gitlab-ci.yml` is in your Bitbucket repository:**
   ```bash
   cd /path/to/your/bitbucket/repo
   # Copy .gitlab-ci.yml from ci-playboooks if not already there
   cp ci-playboooks/.gitlab-ci.yml .
   git add .gitlab-ci.yml
   git commit -m "Add GitLab CI configuration"
   git push
   ```

2. **Note your Bitbucket repository details:**
   - Repository URL: `https://bitbucket.example.com/projects/PROJECT/repos/REPO`
   - Or SSH: `ssh://git@bitbucket.example.com:7999/PROJECT/REPO.git`
   - Project key and repository slug

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
   - Description: `Bitbucket Webhook Trigger`
   - Click "Add trigger"
   - **Copy the trigger token** (save it securely)

2. **Get the trigger URL:**
   - Format: `https://gitlab.example.com/api/v4/projects/PROJECT_ID/trigger/pipeline`
   - Or use: `https://gitlab.example.com/api/v4/projects/PROJECT_ID/ref/REF_NAME/trigger/pipeline`

3. **Note the trigger token format:**
   - You'll need: `token=YOUR_TRIGGER_TOKEN`
   - And: `ref=BRANCH_NAME` (e.g., `master`, `develop`)

### Step 4: Configure Bitbucket Webhook

1. **Go to your Bitbucket repository:**
   - Repository Settings → Webhooks → Add webhook

2. **Configure the webhook:**
   - **Title**: `Trigger GitLab CI/CD`
   - **URL**: 
     ```
     https://gitlab.example.com/api/v4/projects/PROJECT_ID/trigger/pipeline?token=YOUR_TRIGGER_TOKEN&ref=master
     ```
     Replace:
     - `PROJECT_ID` with your GitLab project ID
     - `YOUR_TRIGGER_TOKEN` with the trigger token from Step 3
     - `master` with your default branch name
   
   - **Status**: Active
   - **Triggers**: Select when to trigger:
     - ✅ Repository push
     - ✅ Pull request created
     - ✅ Pull request updated
     - ✅ Pull request merged
     - ✅ Tag created (optional)

3. **Advanced settings:**
   - **SSL/TLS verification**: Enabled (recommended)
   - **HTTP headers** (optional): Add custom headers if needed

4. **Click "Save"**

### Step 5: Configure Dynamic Webhook (Recommended)

Since Bitbucket webhooks need different `ref` values for different branches, you have two options:

#### Option A: Multiple Webhooks (Simple)

Create separate webhooks for each branch:
- Webhook 1: `...&ref=master`
- Webhook 2: `...&ref=develop`
- Webhook 3: `...&ref=release/*`

#### Option B: Use Bitbucket Post-Receive Hook Script (Advanced)

Create a script that dynamically determines the branch and triggers GitLab:

1. **Create a post-receive hook script** in Bitbucket:
   ```bash
   #!/bin/bash
   # /opt/bitbucket/scripts/trigger-gitlab.sh
   
   GITLAB_URL="https://gitlab.example.com/api/v4/projects/PROJECT_ID/trigger/pipeline"
   TRIGGER_TOKEN="YOUR_TRIGGER_TOKEN"
   
   while read oldrev newrev refname; do
       branch=$(git rev-parse --symbolic --abbrev-ref $refname)
       echo "Triggering GitLab pipeline for branch: $branch"
       
       curl -X POST \
         -F "token=${TRIGGER_TOKEN}" \
         -F "ref=${branch}" \
         -F "variables[BITBUCKET_REF]=${refname}" \
         -F "variables[BITBUCKET_COMMIT]=${newrev}" \
         "${GITLAB_URL}"
   done
   ```

2. **Configure in Bitbucket:**
   - Repository Settings → Hooks → Post-receive hook
   - Add the script path or use Bitbucket's hook management

#### Option C: Use Bitbucket REST API (Recommended for Bitbucket Server)

Use Bitbucket's built-in webhook with a custom payload processor or use a simple webhook service.

### Step 6: Configure GitLab CI/CD Variables

1. **In GitLab, go to:**
   - Settings → CI/CD → Variables → Expand

2. **Add required variables:**
   - `ANSIBLE_SSH_KEY_FILE` (Type: **File**, Protected: ✅)
   - `ANSIBLE_VAULT_PASSWORD_FILE` (Type: **File**, Protected: ✅, Masked: ✅)
   - `VCENTER_PASSWORD` (Protected: ✅, Masked: ✅)
   - `BITBUCKET_REPO_URL` (Optional: `https://bitbucket.example.com/projects/PROJECT/repos/REPO.git`)

3. **Add optional variables:**
   - `INVENTORY_PATH`: `/opt/jenkins/inventories/fse/fse-internal`
   - `LIMIT_HOSTGROUP`: `fse_gibraltar`
   - `USE_VCENTER`: `true`
   - `VCENTER_USERNAME`: `administrator@vsphere.local`

4. **Add Bitbucket credentials** (if using private repo):
   - `BITBUCKET_USERNAME` (Protected: ✅)
   - `BITBUCKET_PASSWORD` or `BITBUCKET_APP_PASSWORD` (Protected: ✅, Masked: ✅)

### Step 7: Set Up GitLab Runner

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

3. **Configure runner for Bitbucket access:**
   - Ensure runner can access Bitbucket:
     ```bash
     # Test connectivity
     ping bitbucket.example.com
     
     # Test HTTPS access
     git ls-remote https://bitbucket.example.com/projects/PROJECT/repos/REPO.git
     
     # Test SSH access (if using SSH)
     ssh -T git@bitbucket.example.com
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

### Step 8: Configure Active Directory Integration (Optional)

1. **In GitLab:**
   - Admin Area → Settings → General → Expand "Visibility and access controls"
   - Or: Settings → LDAP (for LDAP/AD integration)

2. **Configure LDAP/AD:**
   - Server: Your AD/LDAP server
   - Port: 389 (LDAP) or 636 (LDAPS)
   - Base DN: `DC=example,DC=com`
   - User filter: `(&(objectClass=user)(sAMAccountName=%{username}))`
   - Attributes mapping:
     - Username: `sAMAccountName`
     - Email: `mail`
     - Name: `displayName`

3. **Test connection:**
   - Use "Test settings" button
   - Verify users can log in

### Step 9: Test the Integration

1. **Make a test commit in Bitbucket:**
   ```bash
   echo "test" >> test.txt
   git add test.txt
   git commit -m "Test GitLab CI trigger"
   git push
   ```

2. **Check Bitbucket webhook:**
   - Go to Repository Settings → Webhooks → Your webhook
   - Click "Recent deliveries" or check webhook logs
   - Verify the webhook was triggered (200 status)

3. **Check GitLab Pipelines:**
   - Go to GitLab → CI/CD → Pipelines
   - You should see a new pipeline triggered
   - Check the pipeline status

4. **Verify pipeline execution:**
   - Click on the pipeline to see job details
   - Check job logs to verify execution
   - Verify Ansible playbooks are running correctly

### Step 10: Configure Branch Protection (Optional)

1. **In GitLab:**
   - Settings → Repository → Protected branches
   - Protect `master` and `main` branches
   - This ensures only authorized users can trigger production pipelines

2. **In Bitbucket:**
   - Repository Settings → Branch permissions
   - Add branch permission for `master` and `main`
   - Require pull request reviews
   - Restrict direct pushes

## Alternative: Using GitLab Mirror Instead of Webhooks

If you prefer to have GitLab mirror the repository (still using Bitbucket as source):

1. **In GitLab project:**
   - Settings → Repository → Mirroring repositories
   - Add pull mirror:
     - **Git repository URL**: `https://bitbucket.example.com/projects/PROJECT/repos/REPO.git`
     - **Mirror direction**: Pull
     - **Trigger**: Every push
     - **Authentication**: Use Bitbucket credentials
   - Save

2. **Use GitLab webhooks or manual triggers:**
   - Pipelines can be triggered manually or via GitLab webhooks
   - Runners clone from GitLab (which is synced from Bitbucket)

## Troubleshooting

### Pipeline Not Triggering

1. **Check Bitbucket webhook logs:**
   - Repository Settings → Webhooks → Recent deliveries
   - Look for error messages or failed requests
   - Check HTTP status codes

2. **Verify trigger token:**
   - Make sure the token is correct in the webhook URL
   - Check GitLab trigger token is still valid
   - Verify token hasn't been revoked

3. **Check GitLab logs:**
   ```bash
   # On GitLab server
   sudo gitlab-ctl tail gitlab-rails/production.log | grep trigger
   ```

4. **Test trigger manually:**
   ```bash
   curl -X POST \
     -F "token=YOUR_TRIGGER_TOKEN" \
     -F "ref=master" \
     "https://gitlab.example.com/api/v4/projects/PROJECT_ID/trigger/pipeline"
   ```

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

### Cannot Clone from Bitbucket

1. **Test network connectivity:**
   ```bash
   ping bitbucket.example.com
   git ls-remote https://bitbucket.example.com/projects/PROJECT/repos/REPO.git
   ```

2. **Check if repository is private:**
   - If private, ensure runner has access
   - Use deploy keys, app passwords, or service accounts
   - For HTTPS: Use `BITBUCKET_USERNAME` and `BITBUCKET_PASSWORD` variables

3. **Test SSH access (if using SSH):**
   ```bash
   ssh -T git@bitbucket.example.com
   # Should return: "logged in as USERNAME"
   ```

4. **Verify Bitbucket credentials:**
   - Check if credentials are correct
   - Verify app password has repository access
   - Check if IP is whitelisted (if Bitbucket has IP restrictions)

### Webhook Authentication Issues

1. **If using trigger tokens:**
   - Verify token is in the webhook URL
   - Check token hasn't expired or been revoked

2. **If using webhook secrets:**
   - Verify secret is configured correctly
   - Check if GitLab expects the secret in headers

3. **Check SSL/TLS:**
   - Verify certificates are valid
   - Check if self-signed certificates need to be trusted

## Security Checklist

- [ ] GitLab trigger token is strong and unique
- [ ] Bitbucket webhook is configured with SSL verification
- [ ] GitLab CI/CD variables are protected and masked where appropriate
- [ ] Runners have minimal required permissions
- [ ] Branch protection is enabled in both Bitbucket and GitLab
- [ ] Webhook deliveries are monitored
- [ ] Audit logs are reviewed regularly
- [ ] AD/LDAP integration is configured (if applicable)
- [ ] Bitbucket credentials are stored securely (GitLab variables)
- [ ] Network access is restricted where possible

## Bitbucket Server vs Data Center

### Bitbucket Server
- Single instance
- Webhooks supported
- REST API available
- Post-receive hooks supported

### Bitbucket Data Center
- Multiple instances (high availability)
- Webhooks supported
- REST API available
- Post-receive hooks supported
- Consider load balancer for webhook URLs

Both versions work with this setup. The main difference is high availability in Data Center.

## Next Steps

- Review [ARCHITECTURE.md](./ARCHITECTURE.md) for architecture details
- See [GITLAB_CI_SETUP.md](./GITLAB_CI_SETUP.md) for detailed GitLab setup
- See [SECURITY.md](./SECURITY.md) for security best practices
- Configure AD/LDAP integration if needed

## Estimated Setup Time

- GitLab project setup: 15 minutes
- Bitbucket webhook configuration: 20-30 minutes
- GitLab CI/CD variables: 15 minutes
- Runner setup: 30-60 minutes
- AD/LDAP integration (optional): 30-60 minutes
- Testing and troubleshooting: 30-60 minutes

**Total: ~2-4 hours** (depending on runner complexity and AD integration)

## Additional Resources

- [Bitbucket Server REST API](https://docs.atlassian.com/bitbucket-server/rest/latest/)
- [Bitbucket Webhooks Documentation](https://confluence.atlassian.com/bitbucketserver/using-webhooks-in-bitbucket-server-938025782.html)
- [GitLab Pipeline Triggers](https://docs.gitlab.com/ee/ci/triggers/)
- [GitLab LDAP Integration](https://docs.gitlab.com/ee/administration/auth/ldap/)

