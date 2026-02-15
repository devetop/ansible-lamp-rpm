# 🚀 Quick Start Guide

Get your shared hosting environment running in 15 minutes!

## Prerequisites

✅ Rocky Linux 9 server (fresh installation recommended)
✅ Root or sudo access
✅ Ansible 2.14+ installed on your control machine
✅ SSH access to the server

## Step-by-Step Deployment

### 1️⃣ Clone and Prepare

```bash
# Clone or copy the framework to your control machine
cd ansible-shared-hosting

# Test connectivity
ansible all -i inventories/production.ini -m ping
```

### 2️⃣ Configure Inventory

Edit `inventories/production.ini`:

```ini
[webservers]
web01.example.com ansible_host=192.168.1.10

[webservers:vars]
ansible_user=root
ansible_python_interpreter=/usr/bin/python3
```

### 3️⃣ Define Your Hosting Users

Edit `group_vars/webservers.yml`:

```yaml
hosting_users:
  - username: myuser
    php_versions:
      - "8.2"
    domains:
      - domain: mysite.com
        php_version: "8.2"
        subdomains:
          - blog
          - shop
```

### 4️⃣ Secure Your Passwords

**CRITICAL STEP - DO NOT SKIP!**

```bash
# Create encrypted vault for sensitive data
ansible-vault create group_vars/webservers/vault.yml
```

Add this content when editor opens:

```yaml
vault_mariadb_root_password: "YourStrongPassword123!@#$"
```

Save and exit (`:wq` in vim).

Update `group_vars/webservers.yml` to reference vault:

```yaml
mariadb_root_password: "{{ vault_mariadb_root_password }}"
```

### 5️⃣ Deploy Everything!

```bash
# Full deployment
ansible-playbook -i inventories/production.ini playbooks/site.yml --ask-vault-pass

# Enter your vault password when prompted
```

### 6️⃣ Verify Deployment

```bash
# Check services
ansible webservers -i inventories/production.ini -m shell -a "systemctl status httpd php82-php-fpm mariadb"

# View deployment report
ansible webservers -i inventories/production.ini -m shell -a "cat /root/shared-hosting-deployment-report.txt"
```

## 🎉 Success! What's Next?

### Test Your Setup

1. **Create a test PHP file:**
```bash
ssh root@web01.example.com
echo '<?php phpinfo(); ?>' > /home/myuser/public_html/info.php
chown myuser:myuser /home/myuser/public_html/info.php
```

2. **Update DNS** to point mysite.com to your server IP

3. **Test in browser:** http://mysite.com/info.php

### Add SSL Certificates

```bash
# Install Certbot
ssh root@web01.example.com
dnf install -y certbot python3-certbot-apache

# Get certificate
certbot --apache -d mysite.com -d www.mysite.com

# Auto-renewal is configured automatically!
```

### View Database Credentials

```bash
ssh root@web01.example.com
cat /home/myuser/db-credentials-mysite_com.txt
```

## 🔧 Common Operations

### Add Another User

Edit `group_vars/webservers.yml` and add to `hosting_users`, then:

```bash
ansible-playbook -i inventories/production.ini playbooks/site.yml --ask-vault-pass
```

Or use the dedicated playbook:

```bash
ansible-playbook -i inventories/production.ini playbooks/add-user.yml \
  -e "new_username=newuser" \
  -e "new_php_versions=['8.2']" \
  -e "new_domain=newsite.com" \
  --ask-vault-pass
```

### Change PHP Version

1. Edit `group_vars/webservers.yml`
2. Change the `php_version` for the domain
3. Run: `ansible-playbook -i inventories/production.ini playbooks/site.yml --tags "apache,php" --ask-vault-pass`

### Deploy Only Specific Components

```bash
# Only Apache changes
ansible-playbook playbooks/site.yml --tags "apache" --ask-vault-pass

# Only PHP-FPM changes
ansible-playbook playbooks/site.yml --tags "php" --ask-vault-pass

# Only MariaDB changes
ansible-playbook playbooks/site.yml --tags "mariadb" --ask-vault-pass
```

## 🐛 Troubleshooting

### Can't Connect to Server

```bash
# Check SSH connection
ssh root@web01.example.com

# Check Ansible inventory
ansible-inventory -i inventories/production.ini --list
```

### Apache Not Starting

```bash
# SSH to server
ssh root@web01.example.com

# Check configuration
httpd -t

# Check logs
journalctl -u httpd -n 50
```

### PHP-FPM Issues

```bash
# Test configuration
/opt/remi/php82/root/usr/sbin/php-fpm -t

# Check service
systemctl status php82-php-fpm

# Check logs
tail -f /var/log/php-fpm/myuser-error.log
```

### Database Connection Failed

```bash
# Check credentials
cat /home/myuser/db-credentials-mysite_com.txt

# Test connection
mysql -u myuser_mysite_com -p myuser_mysite_com
```

### SELinux Blocking Access

```bash
# Check for denials
ausearch -m avc -ts recent

# Fix contexts
restorecon -Rv /home/myuser
```

## 📚 Next Steps

1. **Read the full README.md** for comprehensive documentation
2. **Set up monitoring** (recommended: Prometheus + Grafana)
3. **Configure backups** for databases and user files
4. **Implement fail2ban** for security
5. **Set up log rotation** for application logs
6. **Review security best practices** in BEST_PRACTICES.md

## 🆘 Getting Help

- Check `README.md` for detailed documentation
- Review Ansible logs: `~/.ansible/ansible.log`
- Check service logs: `journalctl -xe`
- Server deployment report: `/root/shared-hosting-deployment-report.txt`

## 💡 Pro Tips

1. **Always use Ansible Vault** for passwords
2. **Test in staging first** before production deployments
3. **Use tags** to deploy only what changed
4. **Keep backups** of your configurations
5. **Document custom changes** you make

---

**Deployment Time:** ~10-15 minutes  
**Difficulty:** Beginner-Friendly  
**Support:** Check README.md and deployment logs
