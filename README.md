# Ansible Shared Hosting Automation Framework

A production-ready, modular Ansible automation framework for building lightweight shared hosting environments on **Rocky Linux 9**. This framework provides automated provisioning of Apache, multi-version PHP-FPM, and MariaDB with per-user isolation and security.

## 🎯 Features

- **Role-Based Architecture**: Clean, reusable, and maintainable
- **Multi-Version PHP Support**: PHP 7.4, 8.1, 8.2 (via Remi Repository)
- **Per-User PHP-FPM Pools**: Complete isolation between users
- **Dynamic VirtualHost Management**: Automatic Apache configuration
- **Database Automation**: Auto-provisioning of databases and users per domain
- **SELinux Integration**: Proper security contexts and policies
- **Production-Ready**: Idempotent, secure, and scalable

## 📋 Requirements

- **Control Node**: Ansible 2.14+
- **Managed Nodes**: Rocky Linux 9
- **Python**: Python 3.6+ on managed nodes
- **Privileges**: Root or sudo access

## 🏗️ Architecture

### Role Overview

```
roles/
├── common_repo/       # System preparation and repository configuration
├── apache/            # Apache HTTPD with dynamic VirtualHosts
├── php_fpm_multi/     # Multi-version PHP-FPM pool management
└── mariadb/           # MariaDB with automated database provisioning
```

### Directory Structure

```
ansible-shared-hosting/
├── inventories/
│   └── production.ini                 # Inventory file
├── group_vars/
│   └── webservers.yml                 # User and domain configuration
├── playbooks/
│   ├── site.yml                       # Main deployment playbook
│   ├── add-user.yml                   # Add new hosting user
│   ├── add-domain.yml                 # Add new domain to existing user
│   └── remove-user.yml                # Remove hosting user
├── roles/
│   ├── common_repo/
│   │   ├── tasks/
│   │   ├── meta/
│   │   └── defaults/
│   ├── apache/
│   │   ├── tasks/
│   │   ├── handlers/
│   │   ├── templates/
│   │   └── meta/
│   ├── php_fpm_multi/
│   │   ├── tasks/
│   │   ├── handlers/
│   │   ├── templates/
│   │   ├── defaults/
│   │   └── meta/
│   └── mariadb/
│       ├── tasks/
│       ├── handlers/
│       ├── templates/
│       ├── defaults/
│       └── meta/
├── ansible.cfg                        # Ansible configuration
└── README.md                          # This file
```

## 🚀 Quick Start

### 1. Configure Inventory

Edit `inventories/production.ini`:

```ini
[webservers]
web01.example.com ansible_host=192.168.1.10

[webservers:vars]
ansible_user=root
ansible_python_interpreter=/usr/bin/python3
```

### 2. Define Hosting Users

Edit `group_vars/webservers.yml`:

```yaml
hosting_users:
  - username: johndoe
    php_versions:
      - "8.2"
    domains:
      - domain: example.com
        php_version: "8.2"
        subdomains:
          - blog
          - shop
```

### 3. Secure MariaDB Root Password

**CRITICAL**: Never store passwords in plain text!

Create an Ansible Vault:

```bash
ansible-vault create group_vars/webservers/vault.yml
```

Add to vault:

```yaml
vault_mariadb_root_password: "YourSecurePassword123!"
```

Update `group_vars/webservers.yml`:

```yaml
mariadb_root_password: "{{ vault_mariadb_root_password }}"
```

### 4. Deploy

```bash
# Test connectivity
ansible webservers -i inventories/production.ini -m ping

# Deploy the full stack
ansible-playbook -i inventories/production.ini playbooks/site.yml --ask-vault-pass

# Deploy specific components only
ansible-playbook -i inventories/production.ini playbooks/site.yml --tags "apache,php"
```

## 📖 Detailed Configuration

### User Configuration Schema

```yaml
hosting_users:
  - username: string              # Linux username
    php_versions: []              # List of PHP versions: ["7.4", "8.1", "8.2"]
    groups: []                    # (Optional) Additional Linux groups
    domains:
      - domain: string            # Domain name (e.g., example.com)
        php_version: string       # PHP version for this domain
        subdomains: []            # List of subdomains
    php_custom_settings:          # (Optional) Custom PHP settings
      key: value
```

### Directory Layout

Each user gets the following structure:

```
/home/username/
├── public_html/                  # Main domain document root
├── blog/                         # Subdomain: blog.domain.com
├── shop/                         # Subdomain: shop.domain.com
├── tmp/                          # PHP upload directory
└── db-credentials-*.txt          # Database credentials (0600)
```

### PHP-FPM Socket Paths

```
/var/opt/remi/php74/run/php-fpm/username.sock
/var/opt/remi/php81/run/php-fpm/username.sock
/var/opt/remi/php82/run/php-fpm/username.sock
```

### Apache VirtualHost Files

```
/etc/httpd/vhosts.d/username-domain_com.conf
/etc/httpd/vhosts.d/username-subdomain.domain_com.conf
```

### Database Naming Convention

```
Main domain:    username_domain_com
Subdomain:      username_subdomain_domain_com
```

## 🔧 Common Operations

### Adding a New User

1. Edit `group_vars/webservers.yml` and add user to `hosting_users`
2. Run: `ansible-playbook -i inventories/production.ini playbooks/site.yml`

Or use the dedicated playbook:

```bash
ansible-playbook -i inventories/production.ini playbooks/add-user.yml \
  -e "new_username=newuser" \
  -e "new_php_versions=['8.2']" \
  -e "new_domain=newdomain.com"
```

### Adding a Domain to Existing User

```bash
ansible-playbook -i inventories/production.ini playbooks/add-domain.yml \
  -e "target_username=johndoe" \
  -e "new_domain=newsite.com" \
  -e "php_version=8.2"
```

### Changing PHP Version for a Domain

1. Update the `php_version` in `group_vars/webservers.yml`
2. Run: `ansible-playbook -i inventories/production.ini playbooks/site.yml --tags "apache,php"`

### Testing Configuration

```bash
# Test Apache configuration
ansible webservers -i inventories/production.ini -m command -a "httpd -t"

# Test PHP-FPM configurations
ansible webservers -i inventories/production.ini -m shell \
  -a "/opt/remi/php82/root/usr/sbin/php-fpm -t"

# Check service status
ansible webservers -i inventories/production.ini -m systemd \
  -a "name=httpd state=started"
```

## 🔒 Security Features

### SELinux Integration

- Proper file contexts (`httpd_sys_content_t`)
- Network connection permissions (`httpd_can_network_connect`)
- User content access (`httpd_read_user_content`)

### PHP Security

- Open basedir restrictions per user
- Dangerous function disabling
- Per-user session directories
- Isolated upload directories

### Database Security

- Scoped privileges (one user per database)
- Strong auto-generated passwords
- No remote root access
- Localhost-only connections by default

### File Permissions

- User home directories: 755
- Web content: 755
- Database credentials: 600 (user-only)
- PHP-FPM sockets: 660 (user + apache group)

## 📊 Performance Tuning

### MariaDB Optimization

Edit `group_vars/webservers.yml`:

```yaml
mariadb_innodb_buffer_pool_size: "4G"  # 50-70% of RAM
mariadb_max_connections: 500
mariadb_query_cache_size: "256M"
```

### PHP-FPM Tuning

```yaml
php_fpm_max_children: 20
php_fpm_start_servers: 4
php_fpm_min_spare_servers: 2
php_fpm_max_spare_servers: 6
php_memory_limit: "512M"
```

### Apache Tuning

```yaml
# Edit /etc/httpd/conf/httpd.conf manually or via template
MaxRequestWorkers: 250
KeepAliveTimeout: 5
```

## 🐛 Troubleshooting

### PHP-FPM Not Starting

```bash
# Check configuration
/opt/remi/php82/root/usr/sbin/php-fpm -t

# Check logs
tail -f /var/log/php-fpm/username-error.log

# Check service status
systemctl status php82-php-fpm
```

### Apache 403 Forbidden

```bash
# Check SELinux contexts
ls -laZ /home/username/public_html

# Restore contexts
restorecon -Rv /home/username

# Check permissions
namei -l /home/username/public_html/index.php
```

### Database Connection Errors

```bash
# Verify credentials
cat /home/username/db-credentials-domain_com.txt

# Test connection
mysql -u username_domain_com -p database_name
```

### Socket Permission Denied

```bash
# Check socket permissions
ls -la /var/opt/remi/php82/run/php-fpm/

# Verify Apache can access
sudo -u apache stat /var/opt/remi/php82/run/php-fpm/username.sock
```

## 🔄 Extending the Framework

### Adding a New PHP Version

1. Update `group_vars/webservers.yml`:

```yaml
hosting_users:
  - username: johndoe
    php_versions:
      - "8.3"  # New version
```

2. Deploy: `ansible-playbook playbooks/site.yml --tags php`

### Adding Custom Apache Modules

Create `roles/apache/tasks/custom-modules.yml` and include it in main tasks.

### Integrating with Monitoring

Add tasks to deploy monitoring agents in `site.yml` post_tasks.

## 📝 Tags Reference

```bash
# Deploy everything
ansible-playbook playbooks/site.yml

# Specific components
--tags "repo"              # Only repository setup
--tags "apache"            # Only Apache
--tags "php"               # Only PHP-FPM
--tags "mariadb"           # Only MariaDB
--tags "apache,php"        # Apache + PHP

# Skip components
--skip-tags "mariadb"      # Everything except MariaDB

# Testing/verification
--tags "test"              # Only verification tasks
```

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Test changes on a staging environment
2. Follow Ansible best practices
3. Update documentation
4. Use meaningful commit messages

## 📄 License

MIT License - See LICENSE file for details

## 🙏 Acknowledgments

- Remi Collet for PHP repositories
- Ansible Community for excellent modules
- Rocky Linux Team

## 📞 Support

For issues and questions:
- Create an issue in the project repository
- Check existing documentation
- Review Ansible logs: `~/.ansible/ansible.log`

## 🔐 Security Notes

1. **Always use Ansible Vault** for sensitive data
2. **Regularly update** system packages
3. **Monitor logs** for suspicious activity
4. **Backup** databases and configurations regularly
5. **Use SSL certificates** (Let's Encrypt recommended)
6. **Implement firewall rules** beyond basic HTTP/HTTPS
7. **Regular security audits** of user content

## 📚 Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Rocky Linux Documentation](https://docs.rockylinux.org/)
- [Apache HTTPD Documentation](https://httpd.apache.org/docs/)
- [PHP-FPM Documentation](https://www.php.net/manual/en/install.fpm.php)
- [MariaDB Documentation](https://mariadb.com/kb/en/)
- [Remi Repository](https://rpms.remirepo.net/)

---

**Version:** 1.0.0  
**Last Updated:** February 2026  
**Maintained By:** DevOps Team
