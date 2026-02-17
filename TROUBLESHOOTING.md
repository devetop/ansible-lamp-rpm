# 🔧 Troubleshooting Guide

Common issues and solutions for the Ansible Shared Hosting Framework.

## Table of Contents
- [Ansible Deployment Issues](#ansible-deployment-issues)
- [Apache Issues](#apache-issues)
- [PHP-FPM Issues](#php-fpm-issues)
- [MariaDB Issues](#mariadb-issues)
- [SELinux Issues](#selinux-issues)
- [Permission Issues](#permission-issues)
- [SSL/TLS Issues](#ssltls-issues)

---

## Ansible Deployment Issues

### Issue: "No hosts matched"

**Symptom:**
```
skipping: no hosts matched
```

**Solution:**
```bash
# Check inventory syntax
ansible-inventory -i inventories/production.ini --list

# Test connection
ansible all -i inventories/production.ini -m ping

# Verify group name in playbook matches inventory
# In site.yml: hosts: webservers
# In inventory: [webservers]
```

### Issue: "Authentication failed"

**Symptom:**
```
Permission denied (publickey,password)
```

**Solution:**
```bash
# Test SSH connection manually
ssh root@server_ip

# Use password authentication (temporary)
ansible-playbook site.yml -k

# Or specify SSH key
ansible-playbook site.yml --private-key ~/.ssh/id_rsa

# Or update inventory
# Add to production.ini:
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### Issue: "Vault password not found"

**Symptom:**
```
ERROR! Attempting to decrypt but no vault secrets found
```

**Solution:**
```bash
# Provide vault password
ansible-playbook site.yml --ask-vault-pass

# Or use password file
echo "your_password" > ~/.vault_pass
chmod 600 ~/.vault_pass
ansible-playbook site.yml --vault-password-file ~/.vault_pass
```

### Issue: Module not found

**Symptom:**
```
ERROR! couldn't resolve module/action 'community.mysql.mysql_db'
```

**Solution:**
```bash
# Install required collections
ansible-galaxy collection install community.mysql
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.general
```

---

## Apache Issues

### Issue: Apache won't start

**Symptom:**
```
Failed to start httpd.service
```

**Diagnosis:**
```bash
# Test configuration
httpd -t

# Check error logs
journalctl -u httpd -n 50

# Check syntax errors
tail -50 /var/log/httpd/error_log

# Verify ports
ss -tlnp | grep :80
```

**Common Causes:**
1. **Port already in use**
   ```bash
   # Find process using port 80
   lsof -i :80
   # Kill or stop conflicting service
   ```

2. **Syntax error in config**
   ```bash
   # Test configuration
   httpd -t
   # Check specific VirtualHost
   httpd -t -D DUMP_VHOSTS
   ```

3. **SELinux blocking**
   ```bash
   # Check denials
   ausearch -m avc -ts recent
   # Fix contexts
   restorecon -Rv /etc/httpd
   ```

### Issue: 403 Forbidden

**Symptom:**
Browser shows "403 Forbidden"

**Diagnosis:**
```bash
# Check file permissions
ls -la /home/username/public_html
namei -l /home/username/public_html/index.php

# Check SELinux contexts
ls -Z /home/username/public_html

# Check Apache error log
tail -f /var/log/httpd/username-domain-error.log
```

**Solutions:**

1. **Fix file permissions**
   ```bash
   # Set correct ownership
   chown -R username:username /home/username/public_html
   
   # Set correct permissions
   chmod 755 /home/username
   chmod 755 /home/username/public_html
   chmod 644 /home/username/public_html/*
   
   # Set ACL for Apache
   setfacl -m u:apache:rx /home/username
   ```

2. **Fix SELinux contexts**
   ```bash
   # Set context
   semanage fcontext -a -t httpd_sys_content_t "/home/username(/.*)?"
   restorecon -Rv /home/username
   
   # Enable boolean
   setsebool -P httpd_read_user_content on
   ```

### Issue: VirtualHost not working

**Diagnosis:**
```bash
# Check VirtualHost configuration
httpd -t -D DUMP_VHOSTS

# Verify VirtualHost file exists
ls -la /etc/httpd/vhosts.d/

# Check if included in main config
grep "IncludeOptional vhosts.d" /etc/httpd/conf/httpd.conf
```

**Solution:**
```bash
# Regenerate VirtualHost
ansible-playbook site.yml --tags apache

# Restart Apache
systemctl restart httpd
```

---

## PHP-FPM Issues

### Issue: PHP not executing

**Symptom:**
PHP files download instead of executing

**Diagnosis:**
```bash
# Check if PHP-FPM is running
systemctl status php82-php-fpm

# Check socket exists
ls -la /var/opt/remi/php82/run/php-fpm/

# Check Apache proxy configuration
grep -r "proxy_fcgi" /etc/httpd/
```

**Solution:**
```bash
# Start PHP-FPM
systemctl start php82-php-fpm

# Check Apache modules
httpd -M | grep proxy_fcgi

# If missing, enable it
echo "LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so" > /etc/httpd/conf.modules.d/00-proxy_fcgi.conf
systemctl restart httpd
```

### Issue: 502 Bad Gateway

**Symptom:**
"502 Bad Gateway" when accessing PHP files

**Diagnosis:**
```bash
# Check PHP-FPM status
systemctl status php82-php-fpm

# Check pool configuration
/opt/remi/php82/root/usr/sbin/php-fpm -t

# Check socket permissions
ls -la /var/opt/remi/php82/run/php-fpm/username.sock

# Check PHP-FPM error log
tail -f /var/log/php-fpm/username-error.log
```

**Solutions:**

1. **Socket permission issue**
   ```bash
   # Verify socket ownership
   ls -la /var/opt/remi/php82/run/php-fpm/*.sock
   
   # Should be: username:apache with 0660
   # If wrong, check pool config
   cat /etc/opt/remi/php82/php-fpm.d/username.conf | grep listen
   ```

2. **PHP-FPM not running**
   ```bash
   systemctl restart php82-php-fpm
   ```

3. **SELinux blocking**
   ```bash
   # Check denials
   ausearch -m avc -ts recent | grep php-fpm
   
   # Fix contexts
   restorecon -Rv /var/opt/remi/php82
   
   # Enable boolean
   setsebool -P httpd_can_network_connect on
   ```

### Issue: Slow PHP execution

**Diagnosis:**
```bash
# Check slow log
tail -f /var/log/php-fpm/username-slow.log

# Check pool status
curl http://localhost/php-fpm-status

# Check system resources
top
free -h
```

**Solutions:**
```bash
# Increase pool size in group_vars/webservers.yml
php_fpm_max_children: 20
php_fpm_start_servers: 5

# Increase memory limit
php_memory_limit: "512M"

# Redeploy
ansible-playbook site.yml --tags php
```

---

## MariaDB Issues

### Issue: Can't connect to database

**Symptom:**
"Connection refused" or "Access denied"

**Diagnosis:**
```bash
# Check if MariaDB is running
systemctl status mariadb

# Test connection
mysql -u root -p

# Check if database exists
mysql -u root -p -e "SHOW DATABASES;"

# Verify credentials
cat /home/username/db-credentials-domain_com.txt
```

**Solutions:**

1. **MariaDB not running**
   ```bash
   systemctl start mariadb
   systemctl enable mariadb
   ```

2. **Wrong credentials**
   ```bash
   # Reset user password
   mysql -u root -p
   ALTER USER 'username_domain_com'@'localhost' IDENTIFIED BY 'new_password';
   FLUSH PRIVILEGES;
   ```

3. **Database doesn't exist**
   ```bash
   # Recreate database
   ansible-playbook site.yml --tags mariadb
   ```

### Issue: "Too many connections"

**Symptom:**
```
ERROR 1040 (HY000): Too many connections
```

**Solution:**
```bash
# Check current connections
mysql -u root -p -e "SHOW PROCESSLIST;"

# Increase max_connections in group_vars/webservers.yml
mariadb_max_connections: 500

# Redeploy
ansible-playbook site.yml --tags mariadb

# Restart MariaDB
systemctl restart mariadb
```

---

## SELinux Issues

### Issue: SELinux blocking Apache

**Diagnosis:**
```bash
# Check SELinux mode
getenforce

# View recent denials
ausearch -m avc -ts recent

# Check specific denials
ausearch -m avc -ts recent | grep httpd
```

**Solutions:**

1. **Fix file contexts**
   ```bash
   # Restore contexts
   restorecon -Rv /home/username
   restorecon -Rv /etc/httpd
   restorecon -Rv /var/opt/remi
   ```

2. **Enable required booleans**
   ```bash
   setsebool -P httpd_can_network_connect on
   setsebool -P httpd_read_user_content on
   setsebool -P httpd_enable_homedirs on
   ```

3. **Add custom policy** (if needed)
   ```bash
   # Generate policy from denials
   ausearch -m avc -ts recent | audit2allow -M mypolicy
   
   # Review policy
   cat mypolicy.te
   
   # Load policy
   semodule -i mypolicy.pp
   ```

### Issue: SELinux preventing PHP-FPM socket access

**Solution:**
```bash
# Set correct context for sockets
semanage fcontext -a -t httpd_var_run_t "/var/opt/remi/php.*/run/php-fpm(/.*)?"
restorecon -Rv /var/opt/remi/php*/run
```

---

## Permission Issues

### Issue: Permission denied errors

**Diagnosis:**
```bash
# Check file ownership and permissions
namei -l /home/username/public_html/file.php

# Check ACLs
getfacl /home/username

# Check process user
ps aux | grep httpd
ps aux | grep php-fpm
```

**Solutions:**

1. **Fix ownership**
   ```bash
   chown -R username:username /home/username
   ```

2. **Fix permissions**
   ```bash
   # Directories: 755
   find /home/username -type d -exec chmod 755 {} \;
   
   # Files: 644
   find /home/username -type f -exec chmod 644 {} \;
   ```

3. **Set ACLs**
   ```bash
   setfacl -R -m u:apache:rx /home/username
   setfacl -R -d -m u:apache:rx /home/username
   ```

---

## SSL/TLS Issues

### Issue: SSL certificate not working

**Diagnosis:**
```bash
# Test SSL
openssl s_client -connect domain.com:443

# Check certificate
echo | openssl s_client -connect domain.com:443 2>/dev/null | openssl x509 -noout -dates

# Check Apache SSL config
httpd -t -D DUMP_VHOSTS | grep 443
```

**Solution:**

1. **Install Let's Encrypt**
   ```bash
   dnf install -y certbot python3-certbot-apache
   certbot --apache -d domain.com -d www.domain.com
   ```

2. **Update VirtualHost**
   Edit VirtualHost file to enable SSL configuration section

3. **Test SSL Configuration**
   https://www.ssllabs.com/ssltest/

---

## Quick Diagnostic Commands

```bash
# Full system check
systemctl status httpd php82-php-fpm mariadb

# Check all logs
journalctl -xe

# Check disk space
df -h

# Check memory
free -h

# Check SELinux denials
ausearch -m avc -ts today

# Test all configurations
httpd -t
/opt/remi/php82/root/usr/sbin/php-fpm -t
mysql -u root -p -e "SELECT 1"
```

---

## Getting More Help

1. **Check deployment report**
   ```bash
   cat /root/shared-hosting-deployment-report.txt
   ```

2. **Review documentation**
   - README.md
   - ARCHITECTURE.md
   - BEST_PRACTICES.md

3. **Enable debug logging**
   ```apache
   # In Apache VirtualHost
   LogLevel debug
   ```

4. **Run Ansible in verbose mode**
   ```bash
   ansible-playbook site.yml -vvv
   ```

---

**Last Updated:** February 2026  
**Version:** 1.0.2
