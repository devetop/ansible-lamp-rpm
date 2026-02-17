# Configuration Validation Script

## check-config.sh

This script validates your configuration before deployment to catch common errors early.

## Usage

```bash
# Make executable (if not already)
chmod +x check-config.sh

# Run validation
./check-config.sh
```

## What It Checks

1. ✓ **Inventory File** (`inventories/production.ini`)
   - File exists
   - Has [webservers] group
   - Has at least one host defined

2. ✓ **Configuration File** (`group_vars/webservers.yml`)
   - File exists
   - `hosting_users` variable is defined
   - `mariadb_root_password` is defined
   - Warns about default/weak passwords

3. ✓ **Ansible Installation**
   - Ansible is installed
   - Shows version information

4. ✓ **Required Collections**
   - community.mysql
   - ansible.posix
   - community.general

5. ✓ **SSH Connectivity**
   - Tests connection to servers in inventory
   - Uses `ansible ping` module

6. ✓ **YAML Syntax**
   - Validates group_vars/webservers.yml syntax
   - Catches YAML formatting errors

## Exit Codes

- **0** - All checks passed or only warnings
- **1** - Errors found, fix before deploying

## Output Examples

### Successful Validation
```
==========================================
Ansible Shared Hosting - Pre-Deploy Check
==========================================

Checking inventory configuration...
✓ Inventory file exists: inventories/production.ini
✓ Inventory has [webservers] group
✓ Inventory has 1 host(s) defined

Checking group_vars configuration...
✓ Configuration file exists: group_vars/webservers.yml
✓ hosting_users variable is defined
✓ mariadb_root_password is defined

...

==========================================
Validation Summary
==========================================
✓ All checks passed! You're ready to deploy.

Next step:
  ansible-playbook -i inventories/production.ini playbooks/site.yml
```

### Failed Validation
```
==========================================
Ansible Shared Hosting - Pre-Deploy Check
==========================================

Checking inventory configuration...
✗ ERROR: Inventory file not found: inventories/production.ini
ℹ   Copy from: inventories/production.ini.example

Checking group_vars configuration...
✗ ERROR: Configuration file not found: group_vars/webservers.yml
ℹ   Copy from: group_vars/webservers.yml.example

...

==========================================
Validation Summary
==========================================
✗ 2 error(s) found. Fix errors before deploying.

For help, see:
  - COMMON_ERRORS.md
  - QUICKSTART.md
  - README.md
```

## Common Issues

### Issue: hosting_users not defined

**Error:**
```
✗ ERROR: hosting_users variable is NOT defined
```

**Fix:**
```bash
# Add to group_vars/webservers.yml:
hosting_users: []
```

### Issue: Inventory has no hosts

**Error:**
```
✗ ERROR: No hosts defined in inventory
```

**Fix:**
Edit `inventories/production.ini` and add your server:
```ini
[webservers]
web01 ansible_host=192.168.1.10
```

### Issue: SSH connectivity failed

**Warning:**
```
⚠ WARNING: SSH connectivity test failed
```

**Fix:**
```bash
# Test SSH manually
ssh root@server_ip

# Check SSH keys
ssh-copy-id root@server_ip

# Or use password authentication
ansible-playbook site.yml -k
```

## Integration with CI/CD

Use in CI/CD pipelines:

```yaml
# GitLab CI example
validate:
  script:
    - ./check-config.sh
  only:
    - merge_requests

deploy:
  script:
    - ansible-playbook -i inventories/production.ini playbooks/site.yml
  only:
    - main
  needs:
    - validate
```

## Tips

1. **Run before every deployment** to catch configuration errors early

2. **Combine with dry-run** for complete validation:
   ```bash
   ./check-config.sh && ansible-playbook site.yml --check
   ```

3. **Add to pre-commit hooks** to prevent committing invalid configs:
   ```bash
   #!/bin/bash
   # .git/hooks/pre-commit
   ./check-config.sh || exit 1
   ```

4. **Use in documentation** when helping users troubleshoot

## Extending the Script

To add custom checks, edit `check-config.sh` and add:

```bash
echo "Checking custom requirement..."
if [ YOUR_CONDITION ]; then
    success "Custom check passed"
else
    error "Custom check failed"
fi
echo ""
```

## See Also

- [COMMON_ERRORS.md](COMMON_ERRORS.md) - Solutions to common errors
- [QUICKSTART.md](QUICKSTART.md) - Quick deployment guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Detailed troubleshooting

---

**Version:** 1.0.3
