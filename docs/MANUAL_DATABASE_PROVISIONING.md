# Manual Database Provisioning Guide

## Overview

The MariaDB role supports **two provisioning modes**:

1. **Auto-provisioning** — Databases and users created automatically from `hosting_users` structure
2. **Manual provisioning** — Databases and users defined explicitly via `mariadb_databases` and `mariadb_users`

This guide covers **manual provisioning** for use cases like:
- Admin / monitoring databases (Grafana, Zabbix)
- Backup users with read-only access
- Application databases separate from web hosting
- CI/CD pipeline databases

---

## Directory Structure

```
ansible-shared-hosting/
├── group_vars/
│   ├── all.yml                    # Global variables (manual DB definitions)
│   └── webservers.yml             # Web hosting-specific (hosting_users)
├── host_vars/
│   └── db01.example.com.yml       # Per-host overrides
├── inventories/
│   └── production.ini
├── playbooks/
│   ├── site.yml                   # Full deployment
│   └── provision-manual-databases.yml  # Manual DBs only
└── roles/
    └── mariadb/
        ├── defaults/main.yml      # Default values
        └── tasks/main.yml         # Provisioning logic
```

---

## Variable Structure

### `mariadb_databases` (list)

```yaml
mariadb_databases:
  - name: database_name        # Required
    collation: utf8mb4_unicode_ci  # Optional, default: utf8mb4_unicode_ci
    encoding: utf8mb4          # Optional, default: utf8mb4
```

### `mariadb_users` (list)

```yaml
mariadb_users:
  - name: username             # Required
    password: "secret"         # Required (use Ansible Vault!)
    priv: "db.*:ALL"           # Required (privilege string)
    host: localhost            # Optional, default: localhost
```

---

## Privilege Format

### Basic Format
```
"database.table:PRIV1,PRIV2,PRIV3"
```

### Scope Examples

| Privilege String | Meaning |
|------------------|---------|
| `*.*:ALL` | Full access to all databases |
| `database_name.*:ALL` | Full access to `database_name` only |
| `database_name.table_name:SELECT` | Read-only on specific table |
| `database_name.*:SELECT,INSERT,UPDATE,DELETE` | CRUD operations only |
| `db1.*:ALL/db2.*:SELECT` | Full access to db1, read-only on db2 |

### Common Privileges

| Privilege | Description |
|-----------|-------------|
| `ALL` | Full access (excludes GRANT) |
| `SELECT` | Read data |
| `INSERT` | Insert new rows |
| `UPDATE` | Modify existing rows |
| `DELETE` | Remove rows |
| `CREATE` | Create databases/tables |
| `DROP` | Delete databases/tables |
| `ALTER` | Modify table structure |
| `INDEX` | Create/drop indexes |
| `GRANT` | Grant privileges to other users |
| `LOCK TABLES` | Lock tables for backup |
| `SHOW VIEW` | View CREATE VIEW statements |
| `PROCESS` | Show all processes |
| `REPLICATION SLAVE` | Read binary logs for replication |
| `REPLICATION CLIENT` | Read replication status |

---

## Examples

### Example 1: WordPress Database

```yaml
# group_vars/all.yml
mariadb_databases:
  - name: wordpress_prod

mariadb_users:
  - name: wp_user
    password: "{{ vault_wp_password }}"
    priv: "wordpress_prod.*:ALL"
    host: localhost
```

### Example 2: Read-Only Backup User

```yaml
mariadb_users:
  - name: backup_ro
    password: "{{ vault_backup_password }}"
    priv: "*.*:SELECT,LOCK TABLES,SHOW VIEW"
    host: localhost
```

### Example 3: Monitoring User

```yaml
mariadb_users:
  - name: monitor
    password: "{{ vault_monitor_password }}"
    priv: "*.*:SELECT,PROCESS,REPLICATION CLIENT"
    host: localhost
```

### Example 4: Developer with Limited Access

```yaml
mariadb_databases:
  - name: dev_staging
  - name: dev_testing

mariadb_users:
  - name: developer
    password: "{{ vault_developer_password }}"
    priv: "dev_staging.*:SELECT,INSERT,UPDATE,DELETE/dev_testing.*:ALL"
    host: localhost
```

### Example 5: Remote Access from Specific IP

```yaml
mariadb_users:
  - name: remote_admin
    password: "{{ vault_remote_admin_password }}"
    priv: "wordpress_prod.*:ALL"
    host: "192.168.1.100"
```

### Example 6: Remote Access from Subnet

```yaml
mariadb_users:
  - name: app_service
    password: "{{ vault_app_service_password }}"
    priv: "production.*:SELECT,INSERT,UPDATE,DELETE"
    host: "10.0.1.%"    # Allow from 10.0.1.0/24
```

---

## Using Ansible Vault (Recommended)

### Step 1: Create Vault File

```bash
ansible-vault create group_vars/all/vault.yml
```

Contents:
```yaml
vault_mariadb_root_password: "ActualRootPassword123!"
vault_wp_password: "ActualWpPassword456!"
vault_backup_password: "ActualBackupPassword789!"
vault_monitor_password: "ActualMonitorPassword012!"
```

### Step 2: Reference in `group_vars/all.yml`

```yaml
mariadb_root_password: "{{ vault_mariadb_root_password }}"

mariadb_users:
  - name: wp_user
    password: "{{ vault_wp_password }}"
    priv: "wordpress_prod.*:ALL"
```

### Step 3: Deploy with Vault Password

```bash
ansible-playbook playbooks/provision-manual-databases.yml --ask-vault-pass
```

Or use a password file:
```bash
echo "your_vault_password" > ~/.vault_pass
chmod 600 ~/.vault_pass

ansible-playbook playbooks/provision-manual-databases.yml \
  --vault-password-file ~/.vault_pass
```

---

## Deployment Workflows

### Workflow 1: Initial Setup

```bash
# 1. Define databases and users
vim group_vars/all.yml

# 2. Create Ansible Vault for passwords
ansible-vault create group_vars/all/vault.yml

# 3. Dry-run
ansible-playbook playbooks/provision-manual-databases.yml \
  --check --diff --ask-vault-pass

# 4. Deploy
ansible-playbook playbooks/provision-manual-databases.yml --ask-vault-pass
```

### Workflow 2: Add New Database

```bash
# 1. Edit group_vars/all.yml — add new entry to mariadb_databases
vim group_vars/all.yml

# 2. Add user to vault
ansible-vault edit group_vars/all/vault.yml

# 3. Deploy only new database (idempotent — won't touch existing)
ansible-playbook playbooks/provision-manual-databases.yml --ask-vault-pass
```

### Workflow 3: Host-Specific Override

```bash
# 1. Create host-specific variables
vim host_vars/db01.example.com.yml

# 2. Deploy to specific host only
ansible-playbook playbooks/provision-manual-databases.yml \
  -l db01.example.com --ask-vault-pass
```

---

## Variable Precedence

Ansible resolves variables in this order (highest to lowest):

1. `-e` command line variables
2. `host_vars/hostname.yml`
3. `group_vars/groupname.yml`
4. `group_vars/all.yml`
5. `roles/rolename/defaults/main.yml`

### Example

```yaml
# group_vars/all.yml
mariadb_databases:
  - name: global_db

# host_vars/db01.example.com.yml
mariadb_databases:
  - name: db01_specific_db

# Result on db01.example.com:
# Only db01_specific_db is created (host_vars overrides group_vars)
```

To merge instead of override, use `hash_behaviour = merge` in `ansible.cfg` (not recommended for beginners).

---

## Integration with Auto-Provisioning

Both modes can coexist:

```yaml
# group_vars/webservers.yml — auto-provisioning
hosting_users:
  - username: devops
    domains:
      - domain: example.com
        php_version: "8.2"

# group_vars/all.yml — manual provisioning
mariadb_databases:
  - name: grafana
mariadb_users:
  - name: grafana_user
    password: "{{ vault_grafana_password }}"
    priv: "grafana.*:ALL"
```

When you run `playbooks/site.yml`:
1. Auto-provisioning creates `devops_example_com` database/user
2. Manual provisioning creates `grafana` database/user

---

## Verification

After deployment:

```bash
# 1. Query databases
mysql -u root -p -e "SHOW DATABASES;"

# 2. Query users
mysql -u root -p -e "SELECT User, Host FROM mysql.user;"

# 3. Test user login
mysql -u wp_user -p -D wordpress_prod -e "SHOW TABLES;"

# 4. Check user privileges
mysql -u root -p -e "SHOW GRANTS FOR 'wp_user'@'localhost';"
```

---

## Troubleshooting

### Issue: User cannot connect

```bash
# Check user exists
mysql -u root -p -e "SELECT User, Host FROM mysql.user WHERE User='username';"

# Verify host matches
# If user was created with host='localhost', connection from 127.0.0.1 may fail
# Solution: create second user with host='127.0.0.1' or use '%' for any host
```

### Issue: Access denied on database

```bash
# Check privileges
mysql -u root -p -e "SHOW GRANTS FOR 'username'@'localhost';"

# Re-apply privileges
ansible-playbook playbooks/provision-manual-databases.yml --ask-vault-pass
```

### Issue: Password not working

```bash
# Verify password in vault
ansible-vault view group_vars/all/vault.yml

# Reset password manually
mysql -u root -p
ALTER USER 'username'@'localhost' IDENTIFIED BY 'new_password';
FLUSH PRIVILEGES;
```

---

## Security Best Practices

1. **Always use Ansible Vault** for passwords
2. **Limit host scope** — use `localhost` or specific IPs, not `%`
3. **Principle of least privilege** — grant only needed permissions
4. **Separate users** — different users for different applications
5. **Read-only where possible** — monitoring/backup users should be SELECT only
6. **Audit regularly** — review `SHOW GRANTS` output
7. **Rotate passwords** — update vault and re-run playbook

---

## Tags Available

| Tag | Effect |
|-----|--------|
| `mariadb` | All mariadb tasks |
| `manual` | Only manual DB/user tasks |
| `manual,databases` | Only create manually-defined databases |
| `manual,users` | Only create manually-defined users |

Example:
```bash
# Only create databases, skip users
ansible-playbook playbooks/provision-manual-databases.yml \
  --tags "manual,databases"
```

---

## See Also

- [QUICKSTART.md](../QUICKSTART.md) — General deployment guide
- [BEST_PRACTICES.md](../BEST_PRACTICES.md) — Security recommendations
- [group_vars/all.yml](../group_vars/all.yml) — Example configuration
- [host_vars/db01.example.com.yml](../host_vars/db01.example.com.yml) — Per-host example

---

**Version:** 1.0.9  
**Last Updated:** February 2026
