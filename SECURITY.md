# Security Best Practices for GitLab CI/CD

This document outlines security best practices for storing and managing secrets in GitLab CI/CD pipelines.

## Is it Safe to Store SSH Keys in GitLab?

**Yes, it's safe!** GitLab provides several secure methods for storing SSH keys and other secrets. Here's what you need to know:

## GitLab Security Features

### Encryption at Rest
- All CI/CD variables are encrypted in GitLab's database
- Uses industry-standard encryption (AES-256)
- Encrypted with keys managed by GitLab

### Access Control
- Variables can be **protected** (only available on protected branches/tags)
- Access is controlled via GitLab project permissions
- Only users with appropriate permissions can view/modify variables

### Audit Trail
- All variable access is logged in GitLab audit logs
- You can see who accessed what and when
- Helps with compliance and security monitoring

### Automatic Cleanup
- File variables are automatically cleaned up after jobs
- No persistent storage of secrets on runners
- Reduces risk of accidental exposure

## Recommended: GitLab File Variables

**File variables are the safest method for SSH keys:**

### Why File Variables are Better

1. **Automatic File Management**
   - GitLab writes the content to a temporary file automatically
   - No manual file creation or cleanup needed
   - Files are automatically deleted after job completion

2. **Proper Permissions**
   - GitLab ensures files have correct permissions (600)
   - No risk of incorrect permissions exposing secrets

3. **No Log Exposure**
   - File paths are used, not the content
   - Secrets don't appear in job logs
   - Reduces risk of accidental logging

4. **Centralized Management**
   - All secrets in one place (GitLab UI)
   - Easy to rotate or update
   - Version history and audit trail

### How to Set Up File Variables

1. Go to **Project → Settings → CI/CD → Variables**
2. Click **"Add variable"**
3. Configure:
   - **Key**: `ANSIBLE_SSH_KEY_FILE`
   - **Value**: Paste your SSH private key (entire key)
   - **Type**: Select **"File"** ⚠️ This is important!
   - **Protected**: ✅ Check (only on protected branches)
   - **Masked**: ❌ Don't check (SSH keys are too long)
   - **Expand variable reference**: ✅ Check

4. The pipeline will automatically use the file path provided by GitLab

## Security Comparison

| Method | Encryption | Access Control | Audit Trail | Auto Cleanup | Risk Level |
|--------|------------|----------------|-------------|--------------|------------|
| **GitLab File Variable** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | 🟢 **Lowest** |
| GitLab Regular Variable | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | 🟡 Low |
| Runner Filesystem | ❌ No* | ⚠️ Limited | ❌ No | ❌ No | 🟠 Medium |
| Hardcoded in Code | ❌ No | ❌ No | ❌ No | ❌ No | 🔴 **Highest** |

*Files on runner filesystem are not encrypted unless the filesystem is encrypted

## Best Practices

### ✅ DO:

1. **Use GitLab File Variables** for SSH keys and large secrets
2. **Enable Protected** flag for production secrets
3. **Use Masked** for passwords (when possible)
4. **Rotate secrets regularly** (every 90 days recommended)
5. **Use separate variables** for different environments
6. **Limit access** to variables (only necessary users)
7. **Review audit logs** periodically
8. **Use protected branches** for production deployments

### ❌ DON'T:

1. **Never commit secrets** to the repository
2. **Don't use regular variables** for SSH keys (use File type)
3. **Don't share variable values** in chat/email
4. **Don't disable protected flag** for sensitive secrets
5. **Don't use the same SSH key** for multiple purposes
6. **Don't store secrets** in job artifacts
7. **Don't log secrets** in pipeline output
8. **Don't use hardcoded values** in `.gitlab-ci.yml`

## SSH Key Management

### Creating a Dedicated CI/CD SSH Key

1. **Generate a new SSH key pair:**
   ```bash
   ssh-keygen -t ed25519 -C "gitlab-ci-ansible" -f ~/.ssh/gitlab-ci-ansible
   ```

2. **Add public key to target servers:**
   ```bash
   ssh-copy-id -i ~/.ssh/gitlab-ci-ansible.pub user@target-server
   ```

3. **Store private key in GitLab:**
   - Copy the private key content
   - Add as File variable: `ANSIBLE_SSH_KEY_FILE`
   - Mark as Protected

4. **Restrict key usage** (optional):
   - Use `command=` restriction in `~/.ssh/authorized_keys` on target servers
   - Limit to specific commands or scripts

### Key Rotation

1. Generate new key pair
2. Add new public key to all target servers
3. Update GitLab variable with new private key
4. Test the pipeline
5. Remove old public key from target servers
6. Delete old GitLab variable

## Compliance Considerations

### SOC 2 / ISO 27001
- GitLab's encryption and access controls help meet compliance requirements
- Audit logs provide necessary documentation
- File variables reduce risk of data exposure

### PCI DSS
- If handling payment data, ensure additional controls
- Consider using dedicated runners in isolated networks
- Implement additional monitoring and alerting

### HIPAA
- GitLab can be configured for HIPAA compliance
- Use protected variables and branches
- Implement strict access controls
- Regular security reviews

## Monitoring and Alerts

### Set Up Alerts For:
- Unauthorized variable access attempts
- Failed pipeline jobs (potential security issues)
- Unusual access patterns
- Variable modifications

### Regular Security Reviews:
- Review who has access to variables (quarterly)
- Audit variable usage logs (monthly)
- Rotate secrets (quarterly or as needed)
- Review and update this document (annually)

## Incident Response

If a secret is compromised:

1. **Immediately rotate** the compromised secret
2. **Revoke access** from compromised systems
3. **Review audit logs** to understand scope
4. **Update all systems** using the secret
5. **Document the incident** and lessons learned
6. **Review security practices** to prevent recurrence

## Additional Resources

- [GitLab CI/CD Variables Documentation](https://docs.gitlab.com/ee/ci/variables/)
- [GitLab Security Best Practices](https://docs.gitlab.com/ee/security/)
- [OWASP Secrets Management](https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_cryptographic_key)
- [NIST Guidelines on Key Management](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final)

## Questions?

If you have security concerns or questions:
1. Review GitLab's security documentation
2. Consult with your security team
3. Consider a security audit
4. Reach out to GitLab support for enterprise features

---

**Remember:** Security is a shared responsibility. While GitLab provides excellent tools, proper configuration and usage are essential.

