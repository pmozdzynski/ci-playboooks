# GitHub Webhook Setup for GitLab CI/CD

This guide explains how to configure GitHub webhooks to trigger GitLab CI/CD pipelines without mirroring the repository.

## Overview

Instead of mirroring the entire repository, we'll use GitHub webhooks to trigger GitLab pipelines. GitLab Runners will clone directly from GitHub when executing jobs.

## Prerequisites

- GitLab CE instance running and accessible
- GitHub repository with admin access
- GitLab project created (can be empty or minimal)

## Step 1: Create GitLab Project

1. **Create a new project in GitLab CE:**
   - Go to GitLab → New Project → Create blank project
   - Name: `vmware` (or your project name)
   - Visibility: Private (recommended)
   - **Do NOT initialize with README** (we'll add `.gitlab-ci.yml` from GitHub)

2. **Note the project URL:**
   - Example: `https://gitlab.example.com/group/vmware`
   - You'll need this for the webhook URL

## Step 2: Add .gitlab-ci.yml to GitHub

The `.gitlab-ci.yml` file should be in your GitHub repository. If it's not there yet:

```bash
# In your GitHub repository
cd /path/to/github/repo
# Copy .gitlab-ci.yml from ci-playboooks directory
cp ci-playboooks/.gitlab-ci.yml .
git add .gitlab-ci.yml
git commit -m "Add GitLab CI configuration"
git push
```

## Step 3: Create GitLab Pipeline Trigger Token

1. **In GitLab, go to your project:**
   - Settings → CI/CD → Pipeline triggers → Expand

2. **Add a new trigger:**
   - Description: `GitHub Webhook Trigger`
   - Click "Add trigger"

3. **Copy the trigger token:**
   - Save the token securely (you'll need it for the webhook)
   - Example token: `abc123def456ghi789`

4. **Note the trigger URL:**
   - Format: `https://gitlab.example.com/api/v4/projects/PROJECT_ID/ref/REF_NAME/trigger/pipeline`
   - Or use the simpler format shown in GitLab UI

## Step 4: Configure GitHub Webhook

1. **Go to your GitHub repository:**
   - Settings → Webhooks → Add webhook

2. **Configure the webhook:**
   - **Payload URL**: 
     ```
     https://gitlab.example.com/api/v4/projects/PROJECT_ID/trigger/pipeline
     ```
     Replace `PROJECT_ID` with your GitLab project ID (found in project settings)
   
   - **Content type**: `application/json`
   
   - **Secret** (optional but recommended): Generate a random secret
     ```bash
     openssl rand -hex 32
     ```
   
   - **Which events**: Select "Just the push event" or customize:
     - ✅ Pushes
     - ✅ Branch or tag creation
     - ✅ Pull requests (optional)

3. **Advanced settings:**
   - ✅ Active: Checked
   - SSL verification: Enabled (recommended)

4. **Click "Add webhook"**

## Step 5: Configure Webhook Payload

GitHub webhooks need to send the trigger token. You have two options:

### Option A: Use GitHub Actions (Recommended)

Create `.github/workflows/trigger-gitlab.yml`:

```yaml
name: Trigger GitLab CI

on:
  push:
    branches: [ master, main, develop ]
  pull_request:
    branches: [ master, main ]

jobs:
  trigger:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger GitLab Pipeline
        run: |
          curl -X POST \
            -F token=${{ secrets.GITLAB_TRIGGER_TOKEN }} \
            -F ref=${{ github.ref_name }} \
            -F "variables[GITHUB_SHA]=${{ github.sha }}" \
            -F "variables[GITHUB_REF]=${{ github.ref }}" \
            -F "variables[GITHUB_REPO]=${{ github.repository }}" \
            https://gitlab.example.com/api/v4/projects/PROJECT_ID/trigger/pipeline
```

Then add `GITLAB_TRIGGER_TOKEN` to GitHub Secrets:
- Settings → Secrets and variables → Actions → New repository secret
- Name: `GITLAB_TRIGGER_TOKEN`
- Value: Your GitLab trigger token

### Option B: Use GitHub Webhook Service

If you prefer not to use GitHub Actions, you can use a webhook service or configure GitHub to send the token directly (requires custom webhook handler).

## Step 6: Update .gitlab-ci.yml for GitHub Clones

The pipeline needs to know to clone from GitHub. Update your `.gitlab-ci.yml`:

```yaml
variables:
  GIT_STRATEGY: clone
  GIT_DEPTH: 1  # Shallow clone to save time and space
  # GitHub repository URL (can be set as CI/CD variable)
  GITHUB_REPO_URL: "https://github.com/YOUR_USERNAME/YOUR_REPO.git"

before_script:
  # If needed, re-clone from GitHub instead of GitLab
  - |
    if [ -n "${GITHUB_REPO_URL}" ] && [ "${CI_PIPELINE_SOURCE}" == "trigger" ]; then
      echo "Cloning from GitHub: ${GITHUB_REPO_URL}"
      git clone --depth 1 --branch "${CI_COMMIT_REF_NAME}" "${GITHUB_REPO_URL}" "${CI_PROJECT_DIR}/github-repo" || true
      # Use GitHub repo if clone successful
      if [ -d "${CI_PROJECT_DIR}/github-repo" ]; then
        cd "${CI_PROJECT_DIR}/github-repo"
      fi
    fi
```

**Note:** Actually, GitLab Runners will clone from wherever the project is configured. Since we're using triggers, we need to configure the runner differently. See Step 7.

## Step 7: Configure GitLab Runner for GitHub Clones

The runner needs to clone from GitHub instead of GitLab. You have two approaches:

### Approach A: Configure Runner to Clone from GitHub

Edit `/etc/gitlab-runner/config.toml`:

```toml
[[runners]]
  name = "ansible-runner"
  url = "https://gitlab.example.com/"
  token = "YOUR_RUNNER_TOKEN"
  executor = "shell"
  [runners.custom_build_dir]
  enabled = true
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  # Override clone URL to use GitHub
  environment = ["GIT_REPO_URL=https://github.com/YOUR_USERNAME/YOUR_REPO.git"]
```

Then modify `.gitlab-ci.yml` to use custom clone:

```yaml
before_script:
  - |
    # Clone from GitHub if GIT_REPO_URL is set
    if [ -n "${GIT_REPO_URL}" ]; then
      echo "Cloning from GitHub: ${GIT_REPO_URL}"
      rm -rf "${CI_PROJECT_DIR}"/* "${CI_PROJECT_DIR}"/.[!.]*
      git clone --depth 1 --branch "${CI_COMMIT_REF_NAME:-master}" "${GIT_REPO_URL}" "${CI_PROJECT_DIR}"
      cd "${CI_PROJECT_DIR}"
    fi
```

### Approach B: Use GitLab Project with External Repository (Recommended)

1. **In GitLab project settings:**
   - Settings → Repository → Mirroring repositories
   - Add push mirror:
     - **Git repository URL**: `https://github.com/YOUR_USERNAME/YOUR_REPO.git`
     - **Mirror direction**: Pull (GitHub → GitLab)
     - **Trigger**: Every push
   - This keeps GitLab in sync but runners still clone from GitLab

2. **Use webhooks to trigger pipelines:**
   - Webhook triggers pipeline
   - Runner clones from GitLab (which is synced from GitHub)
   - Minimal storage (GitLab only stores what's needed)

## Step 8: Test the Webhook

1. **Make a test commit in GitHub:**
   ```bash
   echo "test" >> test.txt
   git add test.txt
   git commit -m "Test webhook trigger"
   git push
   ```

2. **Check GitHub webhook delivery:**
   - Go to Settings → Webhooks → Your webhook → Recent Deliveries
   - Check if the request was successful (200 status)

3. **Check GitLab pipelines:**
   - Go to GitLab → CI/CD → Pipelines
   - You should see a new pipeline triggered
   - Check the pipeline status and logs

## Step 9: Verify Pipeline Execution

1. **Check pipeline logs in GitLab:**
   - CI/CD → Pipelines → Click on the pipeline
   - Verify the job is running

2. **Check runner logs:**
   ```bash
   sudo gitlab-runner --debug run
   ```

3. **Verify GitHub clone:**
   - Check pipeline logs to see if it cloned from GitHub
   - Verify the correct branch/commit is being used

## Troubleshooting

### Webhook Not Triggering

1. **Check webhook delivery in GitHub:**
   - Settings → Webhooks → Recent Deliveries
   - Look for error messages

2. **Verify trigger token:**
   - Make sure the token is correct in the webhook payload
   - Check GitLab trigger token is still valid

3. **Check GitLab logs:**
   ```bash
   sudo gitlab-ctl tail gitlab-rails/production.log | grep trigger
   ```

### Pipeline Not Running

1. **Check pipeline trigger settings:**
   - Verify the trigger token is correct
   - Check if the branch matches workflow rules in `.gitlab-ci.yml`

2. **Check runner status:**
   ```bash
   sudo gitlab-runner status
   sudo gitlab-runner verify
   ```

### Runner Cannot Clone from GitHub

1. **Check network connectivity:**
   ```bash
   # From runner host
   ping github.com
   git ls-remote https://github.com/YOUR_USERNAME/YOUR_REPO.git
   ```

2. **Check SSH access (if using SSH):**
   ```bash
   ssh -T git@github.com
   ```

3. **Verify credentials:**
   - If using private repo, ensure runner has access
   - Use deploy keys or personal access tokens

## Security Best Practices

1. **Use strong trigger tokens:**
   - Generate random tokens
   - Rotate tokens periodically

2. **Use webhook secrets:**
   - Configure secrets in GitHub webhook
   - Verify secrets in GitLab (if using custom handler)

3. **Restrict webhook access:**
   - Use IP whitelisting if possible
   - Monitor webhook deliveries

4. **Protect trigger tokens:**
   - Store tokens in GitHub Secrets (if using Actions)
   - Don't commit tokens to repositories

## Alternative: Using GitLab CI/CD Variables

Instead of webhooks, you can also:

1. **Manually trigger pipelines** from GitLab UI
2. **Use GitLab API** to trigger pipelines programmatically
3. **Use GitHub Actions** to trigger GitLab pipelines (as shown above)

## Next Steps

- See [GITLAB_CI_SETUP.md](./GITLAB_CI_SETUP.md) for runner setup
- See [ARCHITECTURE.md](./ARCHITECTURE.md) for architecture overview
- Configure runners to access GitHub repositories

