# PHP Packages Reference - Remi Repository

## Package Naming Convention

Remi repository uses specific naming for PHP packages on Rocky Linux 9.

### Format

```
php{VERSION}-{COMPONENT}
```

Where:
- `{VERSION}` = PHP version without dots (74, 81, 82)
- `{COMPONENT}` = php-fpm, php-cli, php-mysqlnd, etc.

### Examples

| PHP Version | Package Name         |
|-------------|---------------------|
| 7.4         | php74-php-fpm       |
| 8.1         | php81-php-fpm       |
| 8.2         | php82-php-fpm       |

## Installed Packages

For each PHP version, these packages are installed:

### Core Packages

```
php{VER}-php-fpm        # FastCGI Process Manager
php{VER}-php-cli        # Command Line Interface
php{VER}-php-common     # Common files
```

### Database Support

```
php{VER}-php-mysqlnd    # MySQL Native Driver
php{VER}-php-pdo        # PHP Data Objects
```

### Common Extensions

```
php{VER}-php-gd         # GD graphics library
php{VER}-php-xml        # XML support
php{VER}-php-mbstring   # Multibyte string
php{VER}-php-opcache    # Opcode cache
php{VER}-php-zip        # ZIP archive
php{VER}-php-curl       # cURL support
php{VER}-php-intl       # Internationalization
php{VER}-php-bcmath     # BC Math
php{VER}-php-soap       # SOAP protocol
```

## Complete Package List by Version

### PHP 7.4

```bash
php74-php-fpm
php74-php-cli
php74-php-common
php74-php-mysqlnd
php74-php-gd
php74-php-xml
php74-php-mbstring
php74-php-opcache
php74-php-pdo
php74-php-zip
php74-php-curl
php74-php-intl
php74-php-bcmath
php74-php-soap
```

### PHP 8.1

```bash
php81-php-fpm
php81-php-cli
php81-php-common
php81-php-mysqlnd
php81-php-gd
php81-php-xml
php81-php-mbstring
php81-php-opcache
php81-php-pdo
php81-php-zip
php81-php-curl
php81-php-intl
php81-php-bcmath
php81-php-soap
```

### PHP 8.2

```bash
php82-php-fpm
php82-php-cli
php82-php-common
php82-php-mysqlnd
php82-php-gd
php82-php-xml
php82-php-mbstring
php82-php-opcache
php82-php-pdo
php82-php-zip
php82-php-curl
php82-php-intl
php82-php-bcmath
php82-php-soap
```

## Service Names

Each PHP version has its own service:

```bash
php74-php-fpm.service
php81-php-fpm.service
php82-php-fpm.service
```

## Configuration Paths

### PHP-FPM Config

```
/etc/opt/remi/php74/php-fpm.d/
/etc/opt/remi/php81/php-fpm.d/
/etc/opt/remi/php82/php-fpm.d/
```

### PHP.ini

```
/etc/opt/remi/php74/php.ini
/etc/opt/remi/php81/php.ini
/etc/opt/remi/php82/php.ini
```

### Runtime Directories

```
/var/opt/remi/php74/
/var/opt/remi/php81/
/var/opt/remi/php82/
```

### Binaries

```
/opt/remi/php74/root/usr/bin/php
/opt/remi/php81/root/usr/bin/php
/opt/remi/php82/root/usr/bin/php
```

## Manual Package Operations

### Check Available Packages

```bash
# List all PHP 8.2 packages
dnf list available php82-*

# Search for specific extension
dnf search php82 | grep redis
```

### Install Additional Extension

```bash
# Install Redis extension for PHP 8.2
dnf install php82-php-redis

# Install imagick for PHP 8.1
dnf install php81-php-imagick
```

### Verify Installation

```bash
# Check installed PHP packages
rpm -qa | grep php74
rpm -qa | grep php81
rpm -qa | grep php82

# Verify PHP-FPM
systemctl status php82-php-fpm
```

### Check PHP Version

```bash
# Command line
/opt/remi/php82/root/usr/bin/php -v

# Via FPM (create info.php)
<?php phpinfo(); ?>
```

## Optional Extensions

These extensions are NOT installed by default but are available:

```bash
php{VER}-php-redis      # Redis support
php{VER}-php-memcached  # Memcached
php{VER}-php-imagick    # ImageMagick
php{VER}-php-ldap       # LDAP
php{VER}-php-imap       # IMAP
php{VER}-php-pgsql      # PostgreSQL
php{VER}-php-mongodb    # MongoDB
php{VER}-php-pecl-*     # Various PECL extensions
```

### Install Optional Extension

Edit `group_vars/webservers.yml`:

```yaml
# Add to php_fpm_multi role vars
php_additional_packages:
  - php82-php-redis
  - php82-php-imagick
```

Or install manually after deployment:

```bash
dnf install php82-php-redis php82-php-imagick
systemctl restart php82-php-fpm
```

## Troubleshooting

### Package Not Found

**Error:**
```
No package php82-php-fpm available
```

**Solutions:**

1. **Verify Remi repository is installed:**
   ```bash
   dnf repolist | grep remi
   ```

2. **Enable Remi repository:**
   ```bash
   dnf install https://rpms.remirepo.net/enterprise/remi-release-9.rpm
   ```

3. **Reset PHP module:**
   ```bash
   dnf module reset php -y
   ```

4. **Check repository cache:**
   ```bash
   dnf clean all
   dnf makecache
   ```

### Wrong Package Name

**Common Mistakes:**

❌ `php-8.2-fpm` (wrong format)
❌ `php8.2-fpm` (dots not allowed)
❌ `php-fpm-82` (wrong order)
✅ `php82-php-fpm` (correct!)

### Version Conflicts

**Error:**
```
conflicting requests
```

**Solution:**
```bash
# Remove default PHP
dnf module reset php -y

# Install Remi PHP
dnf install php82-php-fpm
```

## Adding New PHP Version

To add PHP 8.3 (when available):

1. **Update group_vars/webservers.yml:**
   ```yaml
   hosting_users:
     - username: user1
       php_versions:
         - "8.3"  # Add new version
   ```

2. **Framework automatically handles:**
   - Package installation
   - FPM pool creation
   - Service management
   - VirtualHost configuration

No code changes needed!

## Repository Information

### Remi Repository

- **URL:** https://rpms.remirepo.net/
- **Maintainer:** Remi Collet
- **Documentation:** https://blog.remirepo.net/

### GPG Key

```bash
# Import Remi GPG key
rpm --import https://rpms.remirepo.net/RPM-GPG-KEY-remi
```

### Repository Files

```
/etc/yum.repos.d/remi.repo
/etc/yum.repos.d/remi-modular.repo
/etc/yum.repos.d/remi-safe.repo
```

## See Also

- [PHP Official Documentation](https://www.php.net/)
- [Remi Repository Blog](https://blog.remirepo.net/)
- [Rocky Linux Documentation](https://docs.rockylinux.org/)

---

**Version:** 1.0.5  
**Last Updated:** February 2026
