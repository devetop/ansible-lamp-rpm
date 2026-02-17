# Data Structure Guide

## Understanding hosting_users Structure

This guide explains the correct data structure for defining hosting users, domains, and subdomains.

## Basic Structure

```yaml
hosting_users:
  - username: string           # Required: Linux username
    php_versions: [...]        # Required: List of PHP versions
    domains: [...]             # Required: List of domain configurations
    groups: [...]              # Optional: Additional Linux groups
    php_custom_settings: {}    # Optional: Custom PHP settings
```

## Complete Example

```yaml
hosting_users:
  - username: devops
    php_versions:
      - "8.1"
      - "8.2"
    domains:
      - domain: auto.rfan.my.id
        php_version: "8.2"
        subdomains:
          - blog
          - shop
          - api
    groups:
      - wheel
    php_custom_settings:
      max_execution_time: 600
      memory_limit: 512M
```

## Field Definitions

### User Level

#### username (required)
- Type: `string`
- Description: Linux system username
- Example: `devops`, `webuser`, `client1`
- Notes: Must be valid Linux username (lowercase, no spaces)

#### php_versions (required)
- Type: `list of strings`
- Description: PHP versions this user needs
- Available: `"7.4"`, `"8.1"`, `"8.2"`
- Example:
  ```yaml
  php_versions:
    - "8.1"
    - "8.2"
  ```
- Notes: Each version will get a separate PHP-FPM pool

#### domains (required)
- Type: `list of domain objects`
- Description: Domains hosted by this user
- Can be empty: `domains: []`
- See Domain Level below

#### groups (optional)
- Type: `list of strings`
- Description: Additional Linux groups for user
- Example:
  ```yaml
  groups:
    - wheel
    - developers
  ```
- Default: None (user only in own group)

#### php_custom_settings (optional)
- Type: `dictionary`
- Description: Custom PHP.ini settings per user
- Example:
  ```yaml
  php_custom_settings:
    max_execution_time: 600
    memory_limit: 512M
    upload_max_filesize: 128M
  ```
- Default: Uses global defaults from role

### Domain Level

#### domain (required)
- Type: `string`
- Description: Domain name
- Example: `example.com`, `auto.rfan.my.id`
- Notes: Will be used as-is for VirtualHost

#### php_version (required)
- Type: `string`
- Description: PHP version for this specific domain
- Must be: One of the versions in user's `php_versions`
- Example: `"8.2"`
- Notes: Overrides per-domain PHP version

#### subdomains (optional)
- Type: `list of strings`
- Description: Subdomains under this domain
- Can be empty: `subdomains: []`
- Example:
  ```yaml
  subdomains:
    - blog
    - shop
    - api
  ```
- Notes: Each subdomain gets its own directory and database

## Multiple Users Example

```yaml
hosting_users:
  # User 1: E-commerce site
  - username: shopowner
    php_versions:
      - "8.2"
    domains:
      - domain: myshop.com
        php_version: "8.2"
        subdomains:
          - blog
          - admin
          - api

  # User 2: Web agency with multiple clients
  - username: agency
    php_versions:
      - "8.1"
      - "8.2"
    domains:
      - domain: client1.com
        php_version: "8.2"
        subdomains: []
      - domain: client2.net
        php_version: "8.1"
        subdomains:
          - staging
      - domain: agency-website.com
        php_version: "8.2"
        subdomains:
          - portfolio
          - blog

  # User 3: Simple site, no subdomains
  - username: blogger
    php_versions:
      - "8.2"
    domains:
      - domain: myblog.net
        php_version: "8.2"
        subdomains: []
```

## What Gets Created

For this configuration:
```yaml
hosting_users:
  - username: testuser
    php_versions: ["8.2"]
    domains:
      - domain: example.com
        php_version: "8.2"
        subdomains: ["blog", "shop"]
```

### File System
```
/home/testuser/
├── public_html/              # Main domain: example.com
├── blog/                     # Subdomain: blog.example.com
└── shop/                     # Subdomain: shop.example.com
```

### Apache VirtualHosts
```
/etc/httpd/vhosts.d/
├── testuser-example_com.conf              # Main domain
├── testuser-blog.example_com.conf         # blog subdomain
└── testuser-shop.example_com.conf         # shop subdomain
```

### PHP-FPM Pools
```
/etc/opt/remi/php82/php-fpm.d/
└── testuser.conf                          # Pool for testuser
```

### Databases
```sql
testuser_example_com           # Main domain database
testuser_blog_example_com      # blog subdomain database
testuser_shop_example_com      # shop subdomain database
```

## Common Patterns

### Pattern 1: No Subdomains
```yaml
- username: simple
  php_versions: ["8.2"]
  domains:
    - domain: simple.com
      php_version: "8.2"
      subdomains: []  # Empty list or omit entirely
```

### Pattern 2: Multiple Domains, No Subdomains
```yaml
- username: multisite
  php_versions: ["8.2"]
  domains:
    - domain: site1.com
      php_version: "8.2"
      subdomains: []
    - domain: site2.com
      php_version: "8.2"
      subdomains: []
```

### Pattern 3: One Domain, Many Subdomains
```yaml
- username: developer
  php_versions: ["8.2"]
  domains:
    - domain: devsite.local
      php_version: "8.2"
      subdomains:
        - dev
        - staging
        - testing
        - demo
```

### Pattern 4: Multiple PHP Versions
```yaml
- username: legacy
  php_versions:
    - "7.4"  # For old app
    - "8.2"  # For new app
  domains:
    - domain: oldapp.com
      php_version: "7.4"
      subdomains: []
    - domain: newapp.com
      php_version: "8.2"
      subdomains: []
```

### Pattern 5: Complex Multi-Tenant Setup
```yaml
- username: saas_platform
  php_versions: ["8.2"]
  domains:
    - domain: platform.com
      php_version: "8.2"
      subdomains:
        - tenant1
        - tenant2
        - tenant3
        - admin
        - api
```

## Validation Rules

### Username Rules
- ✓ Lowercase letters, numbers, underscore, hyphen
- ✓ 3-32 characters
- ✗ Cannot start with number
- ✗ No special characters except _ and -
- ✗ No spaces

### Domain Rules
- ✓ Valid domain name format
- ✓ Can include TLD (.com, .net, etc.)
- ✗ No http:// or https://
- ✗ No trailing slash

### Subdomain Rules
- ✓ Alphanumeric and hyphen
- ✓ Can be single word
- ✗ No dots (use separate domains instead)
- ✗ No special characters

### PHP Version Rules
- ✓ Must be string: `"8.2"` not `8.2`
- ✓ Must be available: "7.4", "8.1", "8.2"
- ✗ Cannot use unsupported versions

## Testing Your Configuration

Use the validation script:

```bash
./check-config.sh
```

Or test YAML syntax:

```bash
python3 -c "import yaml; print(yaml.safe_load(open('group_vars/webservers.yml')))"
```

Or validate with Ansible:

```bash
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/site.yml --check
```

## Common Mistakes

### ❌ Wrong: Missing Quotes on PHP Version
```yaml
php_versions:
  - 8.2  # Wrong! Will be treated as float
```

### ✓ Correct:
```yaml
php_versions:
  - "8.2"  # Correct! String
```

### ❌ Wrong: Nested Subdomains
```yaml
subdomains:
  - blog.shop  # Wrong! Use separate domains
```

### ✓ Correct:
```yaml
subdomains:
  - blog
  - shop
```

### ❌ Wrong: Empty hosting_users
```yaml
# hosting_users not defined at all
```

### ✓ Correct:
```yaml
hosting_users: []  # Empty but defined
```

### ❌ Wrong: Subdomain as Dictionary
```yaml
subdomains:
  blog:  # Wrong! Should be list
    enabled: true
```

### ✓ Correct:
```yaml
subdomains:
  - blog  # Correct! List item
```

## Troubleshooting

### Error: "subdomains should point to a dictionary"

**Cause:** Incorrect nested subelements syntax

**Solution:** Already fixed in version 1.0.4

### Error: "hosting_users is undefined"

**Solution:** Ensure `group_vars/webservers.yml` contains:
```yaml
hosting_users: []  # Or your actual users
```

### Error: "php_version not in php_versions"

**Cause:** Domain's php_version not in user's php_versions list

**Solution:**
```yaml
- username: user1
  php_versions:
    - "8.2"  # Add this
  domains:
    - domain: example.com
      php_version: "8.2"  # Must match one above
```

## See Also

- [COMMON_ERRORS.md](COMMON_ERRORS.md) - Error solutions
- [QUICKSTART.md](QUICKSTART.md) - Deployment guide
- [group_vars/webservers.yml](../group_vars/webservers.yml) - Full example

---

**Version:** 1.0.4
