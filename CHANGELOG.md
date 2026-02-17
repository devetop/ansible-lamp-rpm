# Changelog

All notable changes to this Ansible Shared Hosting Framework will be documented in this file.

## [1.0.6] - 2026-02-17

### Added
- **Conditional flags** for all database operations in `mariadb` role
- **`mariadb_create_databases`** (default: `false`) — guards all `mysql_db` tasks
- **`mariadb_create_users`** (default: `false`) — guards all `mysql_user` tasks
- **`mariadb_save_credentials`** (default: `false`) — guards credential file tasks
- **`mariadb_apply_config`** (default: `true`) — guards performance tuning template
- **`playbooks/provision-databases.yml`** — dedicated provisioning playbook
- **`host_vars/web01.example.com.yml`** — per-host override example
- Status `debug` messages before each conditional block so operators see what is skipped

### Changed
- `roles/mariadb/defaults/main.yml` rewritten with all boolean flags documented
- `roles/mariadb/tasks/main.yml` rewritten — every DB/user task has `when: flag | bool`
- `group_vars/webservers.yml` updated with flag examples and workflow comment
- `when` conditions use YAML list form (multiple conditions = AND logic)
- Password generation tasks now also gated by `mariadb_create_users | bool`

### Workflow (new)

```
1st deploy or new domain
  → set mariadb_create_databases: true
       mariadb_create_users: true
       mariadb_save_credentials: true
  → ansible-playbook playbooks/provision-databases.yml
  → flags automatically reset (they live only in the playbook vars block)

Routine full-stack run (site.yml)
  → all flags remain false in defaults → DB/user tasks are skipped safely
```

## [1.0.5] - 2026-02-15

### Fixed
- **Critical Bug:** PHP package installation failing with "No package X.X-php-fpm available"
- Fixed PHP package name generation in installation task
- Simplified package installation loop to avoid variable scoping issues

### Changed
- Rewrote PHP package installation task for better clarity
- Added debug task to show package names before installation
- Direct inline templating instead of using intermediate variables

### Technical Details

**Problem:** The vars block with `php_version_clean` wasn't being evaluated correctly in the package list, resulting in incorrect package names like `8.1-php-fpm` instead of `php81-php-fpm`.

**Solution:** Changed from:
```yaml
vars:
  php_version_clean: "{{ item | replace('.', '') }}"
  packages:
    - "php{{ php_version_clean }}-php-fpm"
```

To direct inline templating:
```yaml
name:
  - "php{{ item | replace('.', '') }}-php-fpm"
```

This ensures proper template evaluation at execution time.

### Package Names Reference

For Rocky Linux 9 with Remi repository:
- PHP 7.4: `php74-php-fpm`, `php74-php-cli`, etc.
- PHP 8.1: `php81-php-fpm`, `php81-php-cli`, etc.
- PHP 8.2: `php82-php-fpm`, `php82-php-cli`, etc.

## [1.0.4] - 2026-02-15

### Fixed
- **Critical Bug:** Nested `subelements` filter causing templating errors for subdomain tasks
- Fixed subdomain directory creation in apache role
- Fixed subdomain VirtualHost generation in apache role
- Fixed subdomain database creation in mariadb role
- Fixed subdomain database user creation in mariadb role
- Fixed subdomain credentials saving in mariadb role

### Changed
- Updated all nested `subelements` filters to use correct syntax: `subelements('1.subdomains')`
- Added proper `when` conditions to skip empty subdomain lists

### Technical Details

**Problem:** When using nested `subelements`, the syntax:
```yaml
loop: "{{ hosting_users | subelements('domains') | subelements('subdomains') }}"
```
caused error: "the key subdomains should point to a dictionary"

**Solution:** Changed to:
```yaml
loop: "{{ hosting_users | subelements('domains') | subelements('1.subdomains', skip_missing=True) }}"
when: item.1.subdomains is defined and item.1.subdomains | length > 0
```

This properly references the subdomains list from the domains element (item.1).

### Impact
- Users with subdomains in their configuration can now deploy successfully
- All subdomain-related tasks now work correctly
- No impact on users without subdomains

## [1.0.3] - 2026-02-15

### Fixed
- **Critical Bug:** "hosting_users is undefined" error on first deployment
- Added default empty values for `hosting_users` in role defaults
- Added pre-deployment variable validation in main playbook

### Added
- **COMMON_ERRORS.md** - Comprehensive guide for common deployment errors
- **check-config.sh** - Pre-deployment validation script
- **group_vars/webservers.yml.example** - Example configuration file
- Improved error messages with actionable solutions

### Changed
- Enhanced playbook pre_tasks with variable validation
- Updated README.md with configuration warnings
- Improved documentation for first-time deployment

### How to Fix This Error

If you encounter `'hosting_users' is undefined`:

1. **Quick Fix:** Copy example configuration
   ```bash
   cp group_vars/webservers.yml.example group_vars/webservers.yml
   vim group_vars/webservers.yml  # Customize as needed
   ```

2. **Or:** Ensure `group_vars/webservers.yml` contains:
   ```yaml
   hosting_users: []  # Or your actual user list
   mariadb_root_password: "YourPassword"
   ```

3. **Validate:** Run validation script before deploying
   ```bash
   ./check-config.sh
   ```

See COMMON_ERRORS.md for detailed solutions.

## [1.0.2] - 2026-02-15

### Added
- **roles/apache/templates/httpd.conf.j2** - Complete Apache main configuration template
- **roles/apache/templates/index.php.j2** - Default welcome page template for new sites
- **roles/apache/templates/README.md** - Comprehensive template documentation

### Fixed
- Missing `httpd.conf.j2` template referenced in apache role tasks
- Template directory now fully documented

### Details

#### httpd.conf.j2
Complete Apache HTTPD configuration with:
- MPM configuration (prefork, worker, event)
- Performance tuning (KeepAlive, Timeout, Workers)
- Security hardening (ServerTokens, Headers, SSL/TLS)
- Compression and caching (mod_deflate, mod_expires)
- PHP-FPM proxy configuration
- Protection for sensitive files and directories
- Monitoring endpoints (server-status, server-info)

## [1.0.1] - 2026-02-15

### Added
- Complete `defaults/main.yml` for all roles
- Complete `vars/main.yml` for all roles
- `handlers/main.yml` for common_repo role
- `README.md` in apache/defaults/ directory for variable documentation

### Fixed
- Missing apache role defaults file
- Missing common_repo role defaults and vars files
- Missing vars files for apache, php_fpm_multi, and mariadb roles

### File Structure Now Complete
```
roles/
├── apache/
│   ├── defaults/main.yml      ✅ ADDED
│   ├── defaults/README.md     ✅ ADDED
│   ├── handlers/main.yml      ✅ EXISTS
│   ├── meta/main.yml          ✅ EXISTS
│   ├── tasks/main.yml         ✅ EXISTS
│   ├── templates/             ✅ EXISTS
│   └── vars/main.yml          ✅ ADDED
│
├── common_repo/
│   ├── defaults/main.yml      ✅ ADDED
│   ├── handlers/main.yml      ✅ ADDED
│   ├── meta/main.yml          ✅ EXISTS
│   ├── tasks/main.yml         ✅ EXISTS
│   └── vars/main.yml          ✅ ADDED
│
├── mariadb/
│   ├── defaults/main.yml      ✅ EXISTS
│   ├── handlers/main.yml      ✅ EXISTS
│   ├── meta/main.yml          ✅ EXISTS
│   ├── tasks/main.yml         ✅ EXISTS
│   ├── templates/             ✅ EXISTS
│   └── vars/main.yml          ✅ ADDED
│
└── php_fpm_multi/
    ├── defaults/main.yml      ✅ EXISTS
    ├── handlers/main.yml      ✅ EXISTS
    ├── meta/main.yml          ✅ EXISTS
    ├── tasks/main.yml         ✅ EXISTS
    ├── templates/             ✅ EXISTS
    └── vars/main.yml          ✅ ADDED
```

### Details

#### Apache Role - defaults/main.yml
Added comprehensive default variables including:
- MPM configuration (event, worker, prefork)
- Performance tuning (MaxRequestWorkers, threads)
- KeepAlive settings
- Security settings (ServerTokens, SSL/TLS)
- Module management
- Log format configuration

#### Common Repo Role - defaults/main.yml & vars/main.yml
Added repository management variables:
- EPEL and Remi repository toggles
- Package installation retry logic
- CRB repository configuration
- System package lists

#### All Roles - vars/main.yml
Added role-specific static variables:
- Package names
- Service names
- File paths
- Configuration patterns

## [1.0.0] - 2026-02-15

### Initial Release

#### Features
- Complete modular Ansible framework for shared hosting
- 4 production-ready roles
- Multi-version PHP support (7.4, 8.1, 8.2)
- Dynamic Apache VirtualHost generation
- Automated MariaDB database provisioning
- SELinux and ACL configuration
- Comprehensive documentation

#### Components
- common_repo: Repository and system preparation
- apache: Web server with dynamic VirtualHosts
- php_fpm_multi: Multi-version PHP-FPM pools
- mariadb: Database automation

#### Documentation
- README.md: Complete reference (10,000+ words)
- QUICKSTART.md: 15-minute deployment guide
- BEST_PRACTICES.md: Production best practices
- ARCHITECTURE.md: Technical architecture deep dive
- GET_STARTED.md: Quick orientation guide

#### Playbooks
- site.yml: Main deployment playbook
- add-user.yml: Add hosting user utility
- Deployment report template

#### Templates
- Apache VirtualHost (main domain)
- Apache VirtualHost (subdomain)
- PHP-FPM pool configuration
- PHP custom ini
- MariaDB configuration
- Database credentials

---

## Version History

| Version | Date       | Status           |
|---------|------------|------------------|
| 1.0.1   | 2026-02-15 | Current (Fixed)  |
| 1.0.0   | 2026-02-15 | Initial Release  |

## Upgrade Notes

### From 1.0.0 to 1.0.1

No configuration changes required. The update only adds missing default and vars files that improve role usability and documentation. All existing deployments will continue to work without modification.

If you're using custom variables, review the new `defaults/main.yml` files to see additional options now available for customization.

## Future Roadmap

### Version 1.1.0 (Planned)
- [ ] Let's Encrypt SSL automation
- [ ] Built-in backup scripts
- [ ] Redis/Memcached role
- [ ] Email server integration (Postfix)
- [ ] FTP/SFTP management

### Version 1.2.0 (Planned)
- [ ] Web-based control panel
- [ ] Monitoring stack (Prometheus/Grafana)
- [ ] Resource quota enforcement
- [ ] Container support

### Version 2.0.0 (Future)
- [ ] Kubernetes deployment option
- [ ] Multi-server clustering
- [ ] Advanced load balancing
- [ ] High availability configuration

---

**Maintained by:** DevOps Team  
**License:** MIT  
**Repository:** [Your Repository URL]
