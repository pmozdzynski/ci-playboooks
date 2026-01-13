# Architecture: Source Repository + GitLab CI/CD Integration

This document describes the architecture for using GitHub or Bitbucket as the source of truth while leveraging GitLab CE self-hosted for CI/CD orchestration.

## Overview

This setup allows you to:
- ✅ Keep code in GitHub/Bitbucket (developers continue using their preferred platform)
- ✅ Use GitLab CE self-hosted **only** for CI/CD orchestration
- ✅ Trigger pipelines via webhooks from source repository
- ✅ Minimize storage usage (no full repository duplication)
- ✅ Full pipeline visibility in GitLab UI
- ✅ Optional: Active Directory/LDAP integration for GitLab access

## Supported Source Repositories

This architecture supports:
- **GitHub** (Cloud or Enterprise)
- **Bitbucket Server** (self-hosted)
- **Bitbucket Data Center** (self-hosted, high availability)
- **GitLab** (can also be used as source, though less common in this pattern)

## Architecture Diagram

### GitHub Integration
```
┌─────────────────┐
│   Developers    │
│  Push/Tag in    │
│    GitHub       │
└────────┬────────┘
         │
         │ Webhook (with trigger token)
         │ or GitHub Actions
         │
         ▼
┌─────────────────────────────────────┐
│      GitLab CE (Self-Hosted)        │
│  - Hosts .gitlab-ci.yml             │
│  - Pipeline orchestration           │
│  - Stores only pipeline metadata    │
│  - AD/LDAP authentication (optional) │
└────────┬────────────────────────────┘
         │
         │ Schedule jobs
         │
         ▼
┌─────────────────────────────────────┐
│      GitLab Runners                 │
│  - Clone GitHub repo (shallow)       │
│  - Execute Ansible playbooks        │
│  - Report logs/artifacts to GitLab  │
└─────────────────────────────────────┘
```

### Bitbucket Integration
```
┌─────────────────┐
│   Developers    │
│  Push/Tag in    │
│   Bitbucket     │
│  Server/DC      │
└────────┬────────┘
         │
         │ Webhook (with trigger token)
         │ or Post-receive hook
         │
         ▼
┌─────────────────────────────────────┐
│      GitLab CE (Self-Hosted)        │
│  - Hosts .gitlab-ci.yml             │
│  - Pipeline orchestration           │
│  - Stores only pipeline metadata    │
│  - AD/LDAP authentication (optional) │
└────────┬────────────────────────────┘
         │
         │ Schedule jobs
         │
         ▼
┌─────────────────────────────────────┐
│      GitLab Runners                 │
│  - Clone Bitbucket repo (shallow)   │
│  - Execute Ansible playbooks        │
│  - Report logs/artifacts to GitLab  │
└─────────────────────────────────────┘
```

## Component Roles

| Component | Role |
|-----------|------|
| **Source Repository** (GitHub/Bitbucket) | Source of truth for code; developers push/pull here |
| **GitLab CE** | Hosts `.gitlab-ci.yml`, orchestrates pipelines; receives triggers via webhooks |
| **GitLab Runner(s)** | Executes CI/CD jobs; clones source repo shallowly to save storage |
| **Active Directory** (optional) | Authenticates users via AD/LDAP for GitLab CE access |

## Workflow

### GitHub Workflow
1. **Developer pushes code or creates a tag in GitHub**
2. **GitHub webhook or GitHub Actions triggers GitLab pipeline** (via secure trigger token)
3. **GitLab CE evaluates workflow rules** (branches/tags in `.gitlab-ci.yml`)
4. **GitLab Runner clones only the required branch/tag** from GitHub (shallow clone)
5. **Runner executes infrastructure automation jobs:**
   - Ansible playbooks for configuration management
   - Terraform for infrastructure provisioning
   - kapp for Kubernetes application deployment
6. **Job results, logs, and artifacts** are reported back to GitLab CE

### Bitbucket Workflow
1. **Developer pushes code or creates a tag in Bitbucket**
2. **Bitbucket webhook or post-receive hook triggers GitLab pipeline** (via secure trigger token)
3. **GitLab CE evaluates workflow rules** (branches/tags in `.gitlab-ci.yml`)
4. **GitLab Runner clones only the required branch/tag** from Bitbucket (shallow clone)
5. **Runner executes infrastructure automation jobs:**
   - Ansible playbooks for configuration management
   - Terraform for infrastructure provisioning
   - kapp for Kubernetes application deployment
6. **Job results, logs, and artifacts** are reported back to GitLab CE

## Key Features

### Minimal Storage Usage
- Only `.gitlab-ci.yml`, pipeline metadata, and logs/artifacts are stored in GitLab
- Code is **not mirrored** - runners clone directly from GitHub
- Shallow clones reduce network and storage overhead

### Secure Triggers
- Source repository webhook uses a GitLab **trigger token** to prevent unauthorized pipeline execution
- Optional webhook secret verification for additional security
- GitHub Actions can trigger GitLab pipelines programmatically
- Bitbucket post-receive hooks can trigger GitLab pipelines

### Flexible Runner Setup
- Runners can use shell, Docker, Podman, or Kubernetes executors
- Runners clone from source repository (GitHub/Bitbucket, not GitLab)
- Network connectivity required from runners to source repository
- Supports both HTTPS and SSH cloning methods

## Benefits

| Benefit | Description |
|---------|-------------|
| **Maintain source repository** | No disruption to existing developer workflows (GitHub or Bitbucket) |
| **Automated CI/CD** | Standardized, repeatable builds, tests, and deployments |
| **Pipeline visibility** | Full logs, artifacts, and job status visible in GitLab CE |
| **Resource efficiency** | No full repo duplication; minimal storage usage |
| **Security & compliance** | AD/LDAP authentication, controlled triggers, job isolation via runners |
| **Scalability** | Runners can be added incrementally to handle more jobs |
| **Flexibility** | Works with GitHub, Bitbucket Server, or Bitbucket Data Center |

## Requirements

### Common Requirements
- Self-hosted GitLab CE instance (free edition is sufficient)
- GitLab Runner(s) installed on on-prem servers or containerized environments
- Network connectivity from runners to source repository
- Webhooks configured to trigger pipelines
- Optional: configure shallow or sparse clones to minimize disk usage

### GitHub-Specific
- GitHub repository (cloud or GitHub Enterprise)
- GitHub webhook or GitHub Actions access
- GitHub personal access token or app password (for private repos)

### Bitbucket-Specific
- Bitbucket Server or Bitbucket Data Center instance
- Bitbucket webhook or post-receive hook access
- Bitbucket app password or deploy key (for private repos)
- Optional: Active Directory/LDAP for GitLab user authentication

## Storage Comparison

### Traditional Mirror Approach
- Full repository duplication in GitLab
- Storage: ~2x repository size
- Network: Full clone on every pipeline

### This Approach (Webhook Triggers)
- Only pipeline metadata in GitLab
- Storage: Minimal (logs, artifacts, metadata only)
- Network: Shallow clone from source repository per job

**Example:** For a 1GB repository:
- Mirror approach: ~2GB storage (Source + GitLab)
- Webhook approach: ~50-100MB storage (metadata only)

## Security Considerations

1. **Trigger Tokens**: Use strong, unique tokens for each project
2. **Webhook Secrets**: Configure webhook secrets for verification (GitHub/Bitbucket)
3. **Runner Access**: Ensure runners have appropriate network access to source repository
4. **AD/LDAP Integration**: Use LDAP/AD for GitLab user authentication (especially for Bitbucket setups)
5. **Branch Protection**: Configure workflow rules in `.gitlab-ci.yml`
6. **Repository Credentials**: Store source repository credentials securely in GitLab CI/CD variables
7. **Network Security**: Use VPN or private networks for runner-to-repository communication when possible

## Next Steps

### For GitHub Integration
1. See [SETUP_GITHUB_GITLAB.md](./SETUP_GITHUB_GITLAB.md) for complete setup
2. See [GITHUB_WEBHOOK_SETUP.md](./GITHUB_WEBHOOK_SETUP.md) for webhook configuration
3. See [GITLAB_CI_SETUP.md](./GITLAB_CI_SETUP.md) for GitLab CE setup
4. Configure runners to clone from GitHub (see runner setup guide)

### For Bitbucket Integration
1. See [SETUP_BITBUCKET_GITLAB.md](./SETUP_BITBUCKET_GITLAB.md) for complete setup
2. See [GITLAB_CI_SETUP.md](./GITLAB_CI_SETUP.md) for GitLab CE setup
3. Configure runners to clone from Bitbucket (see runner setup guide)
4. Optional: Configure AD/LDAP integration for GitLab access

## Comparison: GitHub vs Bitbucket

| Feature | GitHub | Bitbucket Server/DC |
|---------|--------|---------------------|
| **Webhook Support** | ✅ Native | ✅ Native |
| **GitHub Actions** | ✅ Available | ❌ Not available |
| **Post-receive Hooks** | ⚠️ Limited | ✅ Full support |
| **REST API** | ✅ Comprehensive | ✅ Comprehensive |
| **AD/LDAP Integration** | ⚠️ Limited | ✅ Full support (via GitLab) |
| **Self-hosted** | ✅ Enterprise only | ✅ Server/DC available |
| **High Availability** | ⚠️ Enterprise feature | ✅ Data Center native |
| **Setup Complexity** | 🟢 Simple | 🟡 Moderate |

Both approaches work well. Choose based on your existing infrastructure and requirements.

