# 🏆 Production Best Practices

Essential guidelines for running a secure, stable, and scalable shared hosting environment.

## 🔐 Security Best Practices

### 1. Password Management

**✅ DO:**
- Store ALL passwords in Ansible Vault
- Use 32+ character passwords with mixed characters
- Rotate passwords every 90 days
- Use different passwords for each service
- Never commit passwords to version control

**❌ DON'T:**
- Store passwords in plain text
- Use default or weak passwords
- Share passwords via email or chat
- Reuse passwords across services

**Example:**
```bash
# Create vault
ansible-vault create group_vars/webservers/vault.yml

# Edit vault
ansible-vault edit group_vars/webservers/vault.yml

# Store vault password securely
echo "your_vault_password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass
```

### 2. SSL/TLS Certificates

**✅ DO:**
- Use Let's Encrypt for free SSL certificates
- Automate certificate renewal
- Force HTTPS redirection
- Use strong cipher suites
- Enable HSTS headers

**Implementation:**
```bash
# Install Certbot
dnf install -y certbot python3-certbot-apache

# Obtain certificate
certbot --apache -d domain.com -d www.domain.com

# Auto-renewal (cron is set up automatically)
systemctl status certbot-renew.timer
```

### 3. File Permissions

**Critical Permissions:**
```bash
/home/username/                     755  (user:user)
/home/username/public_html/         755  (user:user)
/home/username/db-credentials.txt   600  (user:user)
/etc/httpd/conf/                    644  (root:root)
/var/opt/remi/php*/run/             660  (user:apache)
```

**Check Permissions:**
```bash
namei -l /home/username/public_html/index.php
```

### 4. SELinux

**✅ DO:**
- Keep SELinux enabled (enforcing mode)
- Apply proper contexts to all web content
- Monitor SELinux denials regularly

**❌ DON'T:**
- Disable SELinux
- Set SELinux to permissive without reason
- Ignore SELinux denials

**Commands:**
```bash
# Check SELinux status
getenforce

# View denials
ausearch -m avc -ts recent

# Fix contexts
restorecon -Rv /home/username

# Set contexts
semanage fcontext -a -t httpd_sys_content_t "/home/username(/.*)?"
```

### 5. Firewall Configuration

**Minimal Exposure:**
```bash
# Only allow necessary ports
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=ssh

# DO NOT expose MariaDB unless absolutely necessary
# firewall-cmd --permanent --add-service=mysql  # Only for remote DB access

firewall-cmd --reload
```

### 6. SSH Hardening

**Edit `/etc/ssh/sshd_config`:**
```bash
PermitRootLogin no              # Disable root login
PasswordAuthentication no       # Use keys only
Port 2222                       # Change default port
MaxAuthTries 3                  # Limit attempts
ClientAliveInterval 300         # Timeout idle sessions
AllowUsers deploy ansible       # Whitelist users
```

## 💾 Backup Strategy

### 1. What to Backup

**Critical Data:**
- User web content: `/home/*/public_html/`
- User subdomain content: `/home/*/subdomain_name/`
- All databases (MariaDB)
- Apache configuration: `/etc/httpd/`
- PHP-FPM configuration: `/etc/opt/remi/php*/`
- Database credentials: `/home/*/db-credentials-*.txt`

### 2. Backup Frequency

**Recommended Schedule:**
- **Databases:** Hourly incremental, daily full backup
- **Web content:** Daily incremental, weekly full backup
- **Configurations:** On every change + daily

### 3. Database Backup Script

```bash
#!/bin/bash
# /usr/local/bin/backup-databases.sh

BACKUP_DIR="/backup/mysql"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup all databases
mysql -e "SHOW DATABASES;" | grep -Ev "Database|information_schema|performance_schema|mysql" | while read db; do
    mysqldump --single-transaction --routines --triggers "$db" | gzip > "$BACKUP_DIR/${db}_${DATE}.sql.gz"
done

# Keep only last 7 days
find $BACKUP_DIR -type f -mtime +7 -delete

# Verify backups
for file in $BACKUP_DIR/*_${DATE}.sql.gz; do
    gunzip -t "$file" && echo "OK: $file" || echo "CORRUPT: $file"
done
```

**Cron Setup:**
```bash
# Daily database backup at 2 AM
0 2 * * * /usr/local/bin/backup-databases.sh >> /var/log/backup.log 2>&1
```

### 4. Web Content Backup

```bash
#!/bin/bash
# /usr/local/bin/backup-web-content.sh

BACKUP_DIR="/backup/web"
DATE=$(date +%Y%m%d)

mkdir -p $BACKUP_DIR

# Backup all user home directories
for user in $(ls /home); do
    if [ -d "/home/$user/public_html" ]; then
        tar -czf "$BACKUP_DIR/${user}_${DATE}.tar.gz" "/home/$user"
    fi
done

# Keep only last 30 days
find $BACKUP_DIR -type f -mtime +30 -delete
```

## 📊 Monitoring

### 1. Essential Metrics

**Monitor These:**
- CPU usage (alert > 80%)
- Memory usage (alert > 85%)
- Disk space (alert > 90%)
- Apache response time
- PHP-FPM pool status
- MariaDB connections
- Failed login attempts

### 2. Log Monitoring

**Important Logs:**
```bash
/var/log/httpd/*-error.log          # Apache errors
/var/log/php-fpm/*-error.log        # PHP errors
/var/log/php-fpm/*-slow.log         # Slow PHP requests
/var/log/mariadb/mariadb.log        # Database errors
/var/log/mariadb/slow-query.log     # Slow queries
/var/log/secure                     # SSH and authentication
/var/log/audit/audit.log            # SELinux denials
```

**Monitoring Tools:**
- **Prometheus + Grafana** (recommended)
- **Nagios**
- **Zabbix**
- **Datadog** (commercial)

### 3. Health Check Script

```bash
#!/bin/bash
# /usr/local/bin/health-check.sh

# Check critical services
for service in httpd php82-php-fpm mariadb; do
    systemctl is-active --quiet $service || echo "ALERT: $service is down!"
done

# Check disk space
df -h | awk '$5 > 90 {print "ALERT: " $6 " is " $5 " full"}'

# Check failed logins
grep "Failed password" /var/log/secure | tail -10

# Check PHP-FPM pool status
for pool in /var/opt/remi/php*/run/php-fpm/*.sock; do
    [ -S "$pool" ] || echo "ALERT: Pool $pool is missing"
done
```

## 🔧 Performance Optimization

### 1. Apache Tuning

**`/etc/httpd/conf.d/mpm.conf`:**
```apache
<IfModule mpm_event_module>
    StartServers             3
    MinSpareThreads         25
    MaxSpareThreads         75
    ThreadsPerChild         25
    MaxRequestWorkers      400
    MaxConnectionsPerChild  1000
</IfModule>
```

### 2. PHP-FPM Tuning

**Adjust per server resources:**
```yaml
php_fpm_max_children: 20        # Based on available RAM
php_fpm_start_servers: 4
php_fpm_min_spare_servers: 2
php_fpm_max_spare_servers: 6
php_memory_limit: "512M"
```

**Formula:**
```
max_children = (Available RAM - System RAM) / Average PHP Process Size
```

### 3. MariaDB Optimization

**`/etc/my.cnf.d/99-custom.cnf`:**
```ini
innodb_buffer_pool_size = 2G    # 50-70% of total RAM
max_connections = 300
query_cache_size = 128M
innodb_log_file_size = 512M
```

### 4. OPcache Optimization

```yaml
php_opcache_memory: 256              # MB
php_opcache_max_files: 20000
php_opcache_revalidate_freq: 120    # Seconds
```

## 🚦 Deployment Best Practices

### 1. Use Version Control

```bash
# Initialize git repository
git init
git add .
git commit -m "Initial commit"

# Create .gitignore
cat > .gitignore << EOF
group_vars/*/vault.yml
*.retry
.ansible/
*.log
EOF
```

### 2. Test Before Production

```bash
# Always test in staging first
ansible-playbook -i inventories/staging.ini playbooks/site.yml --check

# Use --diff to see what will change
ansible-playbook playbooks/site.yml --diff --check
```

### 3. Use Tags Effectively

```bash
# Deploy only what changed
ansible-playbook playbooks/site.yml --tags "apache"

# Skip components that don't need updates
ansible-playbook playbooks/site.yml --skip-tags "mariadb"
```

### 4. Implement CI/CD

**Example GitHub Actions workflow:**
```yaml
name: Deploy Shared Hosting
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Ansible
        run: |
          ansible-playbook -i inventories/production.ini playbooks/site.yml
```

## 📝 Documentation

### 1. Document Everything

**Maintain Documentation For:**
- Server configurations
- User onboarding procedures
- Troubleshooting guides
- Disaster recovery procedures
- Backup and restore procedures
- Custom modifications

### 2. Change Log

```markdown
# CHANGELOG.md

## [1.1.0] - 2026-02-15
### Added
- PHP 8.3 support
- Automated SSL renewal

### Changed
- Updated PHP-FPM pool defaults
- Improved MariaDB performance settings

### Fixed
- SELinux context for session directories
```

## ⚠️ Common Mistakes to Avoid

### 1. Security Mistakes

❌ Running everything as root
❌ Disabling SELinux or firewall
❌ Using weak passwords
❌ No SSL certificates
❌ Exposing unnecessary ports

### 2. Performance Mistakes

❌ Not tuning PHP-FPM pools
❌ Insufficient database optimization
❌ No caching mechanisms
❌ Running out of disk space
❌ Not monitoring resource usage

### 3. Operational Mistakes

❌ No backups
❌ No monitoring
❌ No documentation
❌ Making changes directly on production
❌ Not testing before deploying

## ✅ Pre-Deployment Checklist

Before going to production:

- [ ] All passwords stored in Ansible Vault
- [ ] SSL certificates configured
- [ ] Firewall rules reviewed and minimal
- [ ] SELinux enabled and configured
- [ ] Backup strategy implemented and tested
- [ ] Monitoring configured
- [ ] Log rotation configured
- [ ] Documentation complete
- [ ] Disaster recovery plan documented
- [ ] Team trained on procedures
- [ ] Change management process defined
- [ ] Staging environment tested
- [ ] Performance testing completed
- [ ] Security audit performed

## 🎯 Recommended Tools

### Security
- **fail2ban** - Intrusion prevention
- **ClamAV** - Antivirus scanning
- **rkhunter** - Rootkit detection
- **OSSEC** - Host intrusion detection

### Monitoring
- **Prometheus + Grafana** - Metrics and dashboards
- **Logwatch** - Log analysis
- **Netdata** - Real-time monitoring
- **StatusCake** - External monitoring

### Backup
- **Duplicity** - Encrypted backups
- **Restic** - Fast backup tool
- **BorgBackup** - Deduplicating backups

### Performance
- **Redis** - Caching layer
- **Varnish** - HTTP accelerator
- **CloudFlare** - CDN and DDoS protection

## 📞 Support Contacts

Maintain a support contact list:

```yaml
support_contacts:
  system_admin: admin@example.com
  database_admin: dba@example.com
  security_team: security@example.com
  emergency_phone: +1-555-0100
```

---

**Remember:** Security and stability should never be compromised for convenience!
