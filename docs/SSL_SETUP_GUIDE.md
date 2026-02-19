# SSL/TLS Setup Guide

## Overview

The Apache role supports **two SSL certificate options**:

| Option | Source | Best For |
|--------|--------|----------|
| **A. Manual** | Existing certificates from CA or self-signed | Enterprise CAs, wildcard certs, offline systems |
| **B. Let's Encrypt** | Automated via Certbot | Free SSL, auto-renewal, internet-facing servers |

You can use **both options simultaneously** for different domains.

---

## Quick Start

### Option A: Manual Certificates (5 minutes)

```bash
# 1. Copy certificates to server
scp example.com.crt root@server:/etc/ssl/certs/
scp example.com.key root@server:/etc/ssl/private/
ssh root@server "chmod 600 /etc/ssl/private/example.com.key"

# 2. Configure group_vars/webservers.yml
apache_enable_ssl: true
apache_enable_letsencrypt: false
apache_ssl_certificates:
  example.com:
    cert: /etc/ssl/certs/example.com.crt
    key: /etc/ssl/private/example.com.key

# 3. Deploy
ansible-playbook playbooks/site.yml --tags apache,ssl
```

### Option B: Let's Encrypt (2 minutes)

```bash
# 1. Configure group_vars/webservers.yml
apache_enable_ssl: true
apache_enable_letsencrypt: true
apache_letsencrypt_email: "admin@example.com"

# 2. Deploy
ansible-playbook playbooks/site.yml --tags apache,ssl,letsencrypt
```

---

## Option A: Manual SSL Certificates

### Prerequisites

1. Valid SSL certificate (`.crt` or `.pem`) from a CA
2. Private key (`.key`) matching the certificate
3. Optional: Intermediate/chain certificate

### Step 1: Obtain Certificates

#### From a Commercial CA (Recommended)

Purchase from: Sectigo, DigiCert, GlobalSign, etc.

1. Generate CSR:
```bash
openssl req -new -newkey rsa:2048 -nodes \
  -keyout example.com.key \
  -out example.com.csr \
  -subj "/C=US/ST=California/L=San Francisco/O=Company/CN=example.com"
```

2. Submit CSR to CA
3. Download certificate files from CA

#### Self-Signed (Testing Only)

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout example.com.key \
  -out example.com.crt \
  -subj "/C=US/ST=CA/L=SF/O=Company/CN=example.com"
```

⚠️ **Warning:** Browsers will show security warnings for self-signed certificates.

### Step 2: Deploy Certificates to Server

```bash
# Copy to server
scp example.com.crt root@server:/etc/ssl/certs/
scp example.com.key root@server:/etc/ssl/private/
scp example.com-chain.crt root@server:/etc/ssl/certs/  # if you have chain

# Set permissions
ssh root@server << 'EOF'
chmod 644 /etc/ssl/certs/example.com.crt
chmod 600 /etc/ssl/private/example.com.key
chown root:root /etc/ssl/certs/example.com.crt
chown root:root /etc/ssl/private/example.com.key
EOF
```

### Step 3: Configure Ansible

Edit `group_vars/webservers.yml`:

```yaml
apache_enable_ssl: true
apache_enable_letsencrypt: false

apache_ssl_certificates:
  example.com:
    cert: /etc/ssl/certs/example.com.crt
    key: /etc/ssl/private/example.com.key
    chain: /etc/ssl/certs/example.com-chain.crt  # optional

  another-domain.net:
    cert: /etc/ssl/certs/another.crt
    key: /etc/ssl/private/another.key
```

### Step 4: Deploy

```bash
ansible-playbook -i inventories/production.ini playbooks/site.yml \
  --tags apache,ssl
```

### Wildcard Certificates

Use one certificate for `*.example.com` AND `example.com`:

```yaml
apache_ssl_certificates:
  example.com:
    cert: /etc/ssl/certs/wildcard.example.com.crt
    key: /etc/ssl/private/wildcard.example.com.key
```

The VirtualHost template automatically uses the parent domain certificate for subdomains.

---

## Option B: Let's Encrypt (Certbot)

### Prerequisites

1. Domain DNS **must** point to the server (A record)
2. Port 80 and 443 **must** be open in firewall
3. Apache **must** be running
4. Valid email address for renewal notifications

### Step 1: Configure Ansible

Edit `group_vars/webservers.yml`:

```yaml
apache_enable_ssl: true
apache_enable_letsencrypt: true
apache_letsencrypt_email: "admin@example.com"  # REQUIRED

# Optional: Use staging server for testing (avoids rate limits)
apache_certbot_staging: false

# Optional: Custom renewal hook
apache_certbot_renew_hook: "systemctl reload httpd"
```

### Step 2: Deploy

```bash
ansible-playbook -i inventories/production.ini playbooks/site.yml \
  --tags apache,ssl,letsencrypt
```

### What Happens

1. Ansible installs `certbot` and `python3-certbot-apache`
2. Certbot requests certificates for all domains in `hosting_users`
3. Certificates are saved to `/etc/letsencrypt/live/[domain]/`
4. Apache VirtualHosts are configured to use the certificates
5. Automatic renewal timer is enabled

### Certificate Locations

```
/etc/letsencrypt/
├── live/
│   ├── example.com/
│   │   ├── fullchain.pem  → used by Apache
│   │   ├── privkey.pem    → used by Apache
│   │   ├── cert.pem
│   │   └── chain.pem
│   └── subdomain.example.com/
│       └── ...
├── renewal/
│   └── example.com.conf
└── archive/
    └── ...
```

### Automatic Renewal

Certificates auto-renew via `certbot-renew.timer` (systemd timer).

Check status:
```bash
systemctl status certbot-renew.timer
certbot renew --dry-run
```

Manual renewal:
```bash
certbot renew
systemctl reload httpd
```

### Rate Limits

Let's Encrypt has rate limits:
- 50 certificates per registered domain per week
- 5 duplicate certificates per week

Use `apache_certbot_staging: true` for testing to avoid hitting limits.

---

## Mixed Mode: Both Options

You can use manual certs for some domains and Let's Encrypt for others:

```yaml
apache_enable_ssl: true
apache_enable_letsencrypt: true
apache_letsencrypt_email: "admin@example.com"

apache_ssl_certificates:
  # This domain uses manual certificate
  legacy-site.com:
    cert: /etc/ssl/certs/legacy.crt
    key: /etc/ssl/private/legacy.key

hosting_users:
  - username: user1
    domains:
      - domain: legacy-site.com    # Uses manual cert
      - domain: new-site.com       # Gets Let's Encrypt cert
      - domain: another.com        # Gets Let's Encrypt cert
```

The template logic:
1. Check if Let's Encrypt is enabled → use `/etc/letsencrypt/live/[domain]/`
2. Else check if domain is in `apache_ssl_certificates` → use manual path
3. Else use fallback self-signed certificate

---

## SSL Configuration Options

### Protocol & Cipher Suite

```yaml
# Modern configuration (recommended)
apache_ssl_protocol: "all -SSLv3 -TLSv1 -TLSv1.1"

apache_ssl_cipher_suite: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"
```

Test with: https://www.ssllabs.com/ssltest/

### HSTS (HTTP Strict Transport Security)

```yaml
apache_hsts_enabled: true
apache_hsts_max_age: 31536000         # 1 year
apache_hsts_include_subdomains: true
apache_hsts_preload: false            # Submit to browser preload lists
```

⚠️ **Warning:** Only enable HSTS after confirming SSL works. Once enabled, browsers will refuse HTTP connections even if SSL breaks.

### OCSP Stapling

```yaml
apache_ssl_stapling: true
apache_ssl_stapling_cache: "shmcb:/var/run/ocsp(128000)"
```

Improves SSL handshake performance.

---

## Verification & Testing

### 1. Check Apache Configuration

```bash
httpd -t
httpd -t -D DUMP_VHOSTS
```

### 2. Test HTTP → HTTPS Redirect

```bash
curl -I http://example.com
# Should return: HTTP/1.1 301 Moved Permanently
# Location: https://example.com/
```

### 3. Test HTTPS Connection

```bash
curl -v https://example.com
openssl s_client -connect example.com:443 -servername example.com
```

### 4. Check Certificate Details

```bash
echo | openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -noout -dates -subject -issuer
```

### 5. SSL Labs Test

https://www.ssllabs.com/ssltest/analyze.html?d=example.com

Target: **A+ rating**

### 6. Check HSTS Header

```bash
curl -I https://example.com | grep -i strict
# Strict-Transport-Security: max-age=31536000; includeSubDomains
```

---

## Troubleshooting

### Issue: Apache won't start after SSL enabled

```bash
# Check logs
journalctl -u httpd -n 50

# Common causes:
# 1. Certificate file not found
ls -la /etc/ssl/certs/example.com.crt
# 2. Permission denied on private key
ls -la /etc/ssl/private/example.com.key  # Should be 600
# 3. Certificate/key mismatch
openssl x509 -noout -modulus -in cert.crt | openssl md5
openssl rsa -noout -modulus -in key.key | openssl md5
# MD5 hashes should match
```

### Issue: Browser shows "Certificate not trusted"

**Self-signed certificate:**
Expected — add exception in browser or use Let's Encrypt.

**Let's Encrypt certificate:**
```bash
# Check certificate chain
openssl s_client -connect example.com:443 -showcerts

# Verify chain file exists
ls -la /etc/letsencrypt/live/example.com/fullchain.pem
```

### Issue: Let's Encrypt fails with "DNS problem"

```bash
# Verify DNS
dig +short example.com
nslookup example.com

# Must return server's public IP
```

### Issue: Certbot rate limit exceeded

```bash
# Use staging server for testing
apache_certbot_staging: true

# Or wait 1 week for rate limit reset
```

### Issue: Renewal fails

```bash
# Test renewal
certbot renew --dry-run

# Check renewal config
cat /etc/letsencrypt/renewal/example.com.conf

# Manual renewal
certbot renew --force-renewal
systemctl reload httpd
```

---

## Security Best Practices

1. **Use strong ciphers** — Disable weak TLS versions and ciphers
2. **Enable HSTS** — Force HTTPS after confirming SSL works
3. **OCSP Stapling** — Enable for better performance
4. **Monitor expiration** — Set up alerts 30 days before expiry
5. **Secure private keys** — chmod 600, never commit to git
6. **Test regularly** — Use SSL Labs every quarter
7. **Keep updated** — Update Certbot and Apache regularly

---

## Certificate Renewal

### Let's Encrypt (Automatic)

Handled by `certbot-renew.timer`:

```bash
# Check timer status
systemctl status certbot-renew.timer

# View next run
systemctl list-timers | grep certbot

# Manual trigger
systemctl start certbot-renew.service
```

### Manual Certificates

Set a reminder 30 days before expiration:

```bash
# Check expiration
openssl x509 -in /etc/ssl/certs/example.com.crt -noout -enddate

# Renew with CA
# 1. Generate new CSR
# 2. Submit to CA
# 3. Download new certificate
# 4. Deploy with Ansible
ansible-playbook playbooks/site.yml --tags apache,ssl
```

---

## Tags Reference

| Tag | Effect |
|-----|--------|
| `apache` | All Apache tasks |
| `ssl` | SSL setup tasks |
| `ssl,install` | Install mod_ssl only |
| `ssl,validate` | Validate manual cert paths |
| `ssl,letsencrypt` | Let's Encrypt tasks only |

Examples:
```bash
# Install SSL support without requesting certificates
ansible-playbook site.yml --tags "ssl,install"

# Only request Let's Encrypt certificates
ansible-playbook site.yml --tags "ssl,letsencrypt"

# Full SSL deployment
ansible-playbook site.yml --tags apache,ssl
```

---

## See Also

- [group_vars/webservers-ssl-example.yml](../group_vars/webservers-ssl-example.yml) — Configuration examples
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [SSL Labs Server Test](https://www.ssllabs.com/ssltest/)

---

**Version:** 1.0.10  
**Last Updated:** February 2026
