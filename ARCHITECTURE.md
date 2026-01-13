# Architecture: GitHub + GitLab CI/CD Integration

This document describes the architecture for using GitHub as the source of truth while leveraging GitLab CE self-hosted for CI/CD orchestration.

## Overview

This setup allows you to:
- ✅ Keep code in GitHub (developers continue using GitHub)
- ✅ Use GitLab CE self-hosted **only** for CI/CD orchestration
- ✅ Trigger pipelines via GitHub webhooks
- ✅ Minimize storage usage (no full repository duplication)
- ✅ Full pipeline visibility in GitLab UI

## Architecture Diagram

```
┌─────────────────┐
│   Developers    │
│  Push/Tag in    │
│    GitHub       │
└────────┬────────┘
         │
         │ Webhook (with trigger token)
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
│  - Clone GitHub repo (shallow)      │
│  - Execute Ansible playbooks        │
│  - Report logs/artifacts to GitLab  │
└─────────────────────────────────────┘
```

## Component Roles

| Component | Role |
|-----------|------|
| **GitHub** | Source of truth for code; developers push/pull here |
| **GitLab CE** | Hosts `.gitlab-ci.yml`, orchestrates pipelines; receives triggers via webhooks |
| **GitLab Runner(s)** | Executes CI/CD jobs; clones GitHub repo shallowly to save storage |
| **Active Directory** (optional) | Authenticates users via AD/LDAP for GitLab CE access |

## Workflow

1. **Developer pushes code or creates a tag in GitHub**
2. **GitHub webhook triggers GitLab pipeline** (via secure trigger token)
3. **GitLab CE evaluates workflow rules** (branches/tags in `.gitlab-ci.yml`)
4. **GitLab Runner clones only the required branch/tag** from GitHub (shallow clone)
5. **Runner executes Ansible playbooks** and other jobs
6. **Job results, logs, and artifacts** are reported back to GitLab CE

## Key Features

### Minimal Storage Usage
- Only `.gitlab-ci.yml`, pipeline metadata, and logs/artifacts are stored in GitLab
- Code is **not mirrored** - runners clone directly from GitHub
- Shallow clones reduce network and storage overhead

### Secure Triggers
- GitHub webhook uses a GitLab **trigger token** to prevent unauthorized pipeline execution
- Optional webhook secret verification for additional security

### Flexible Runner Setup
- Runners can use shell, Docker, Podman, or Kubernetes executors
- Runners clone from GitHub (not GitLab)
- Network connectivity required from runners to GitHub

## Benefits

| Benefit | Description |
|---------|-------------|
| **Maintain GitHub as source** | No disruption to existing developer workflows |
| **Automated CI/CD** | Standardized, repeatable builds, tests, and deployments |
| **Pipeline visibility** | Full logs, artifacts, and job status visible in GitLab CE |
| **Resource efficiency** | No full repo duplication; minimal storage usage |
| **Security & compliance** | AD authentication, controlled triggers, job isolation via runners |
| **Scalability** | Runners can be added incrementally to handle more jobs |

## Requirements

- Self-hosted GitLab CE instance (free edition is sufficient)
- GitLab Runner(s) installed on on-prem servers or containerized environments
- Network connectivity from runners to GitHub repository
- GitHub webhooks configured to trigger pipelines
- Optional: configure shallow or sparse clones to minimize disk usage

## Storage Comparison

### Traditional Mirror Approach
- Full repository duplication in GitLab
- Storage: ~2x repository size
- Network: Full clone on every pipeline

### This Approach (Webhook Triggers)
- Only pipeline metadata in GitLab
- Storage: Minimal (logs, artifacts, metadata only)
- Network: Shallow clone from GitHub per job

**Example:** For a 1GB repository:
- Mirror approach: ~2GB storage (GitHub + GitLab)
- Webhook approach: ~50-100MB storage (metadata only)

## Security Considerations

1. **Trigger Tokens**: Use strong, unique tokens for each project
2. **Webhook Secrets**: Configure GitHub webhook secrets for verification
3. **Runner Access**: Ensure runners have appropriate network access to GitHub
4. **AD Integration**: Use LDAP/AD for GitLab user authentication
5. **Branch Protection**: Configure workflow rules in `.gitlab-ci.yml`

## Next Steps

1. See [GITHUB_WEBHOOK_SETUP.md](./GITHUB_WEBHOOK_SETUP.md) for webhook configuration
2. See [GITLAB_CI_SETUP.md](./GITLAB_CI_SETUP.md) for GitLab CE setup
3. Configure runners to clone from GitHub (see runner setup guide)

