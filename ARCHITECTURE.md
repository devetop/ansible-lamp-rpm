# 📐 Architecture & Design Overview

## Project Vision

This Ansible framework automates the deployment and management of a production-grade shared hosting environment on Rocky Linux 9. It provides complete user isolation, multi-version PHP support, and automated database provisioning while maintaining enterprise-level security and performance.

## Core Design Principles

### 1. Modularity
- **Role-Based Architecture**: Each component (Apache, PHP-FPM, MariaDB) is a separate, reusable role
- **Clean Separation**: Roles have minimal dependencies and well-defined interfaces
- **Extensibility**: Easy to add new features or integrate additional services

### 2. Idempotency
- **Safe Re-Runs**: Playbooks can be run multiple times without side effects
- **State Management**: Ansible ensures desired state, not just execution of commands
- **Predictability**: Same input always produces the same output

### 3. Security First
- **Principle of Least Privilege**: Users and services run with minimal permissions
- **Defense in Depth**: Multiple layers of security (SELinux, firewall, file permissions)
- **Secrets Management**: Sensitive data encrypted with Ansible Vault
- **Isolation**: Complete separation between users and their resources

### 4. Production Ready
- **Error Handling**: Comprehensive validation and error checking
- **Monitoring Hooks**: Built-in support for monitoring integration
- **Documentation**: Extensive inline and external documentation
- **Best Practices**: Follows Ansible and Linux security best practices

## Architectural Components

### Layer 1: Infrastructure (common_repo)
```
┌─────────────────────────────────────┐
│     System Repositories             │
│  ┌──────────┐  ┌──────────┐        │
│  │   EPEL   │  │   Remi   │        │
│  └──────────┘  └──────────┘        │
│                                     │
│     System Dependencies             │
│  ┌──────────────────────────┐      │
│  │ SELinux, ACL, Python3    │      │
│  └──────────────────────────┘      │
└─────────────────────────────────────┘
```

**Purpose**: Prepares the system for web hosting stack installation
**Key Tasks**:
- EPEL and Remi repository installation
- PHP module reset for multi-version support
- Essential package installation
- Dependency management

### Layer 2: Web Server (apache)
```
┌─────────────────────────────────────────┐
│         Apache HTTPD                    │
│  ┌───────────────────────────────┐     │
│  │   Dynamic VirtualHost Engine  │     │
│  │                               │     │
│  │  ┌──────────┐  ┌──────────┐  │     │
│  │  │ Main     │  │Subdomain │  │     │
│  │  │ Domain   │  │ Domain   │  │     │
│  │  └────┬─────┘  └────┬─────┘  │     │
│  └───────┼─────────────┼────────┘     │
│          │             │              │
│  ┌───────▼─────────────▼────────┐     │
│  │   PHP-FPM Proxy (FastCGI)   │     │
│  └─────────────────────────────┘     │
└─────────────────────────────────────────┘
```

**Purpose**: HTTP server with dynamic VirtualHost generation
**Key Features**:
- Per-user VirtualHost configurations
- Main domain and subdomain support
- PHP-FPM integration via Unix sockets
- SELinux and ACL configuration
- Security headers

**File Structure**:
```
/etc/httpd/vhosts.d/
├── username-domain_com.conf
├── username-subdomain.domain_com.conf
└── ...
```

### Layer 3: Application Layer (php_fpm_multi)
```
┌─────────────────────────────────────────────┐
│       Multi-Version PHP-FPM                 │
│                                             │
│  ┌──────────────┐  ┌──────────────┐        │
│  │   PHP 7.4    │  │   PHP 8.1    │        │
│  │              │  │              │        │
│  │ ┌──────────┐ │  │ ┌──────────┐ │        │
│  │ │User1 Pool│ │  │ │User1 Pool│ │        │
│  │ └──────────┘ │  │ └──────────┘ │   ...  │
│  │ ┌──────────┐ │  │ ┌──────────┐ │        │
│  │ │User2 Pool│ │  │ │User2 Pool│ │        │
│  │ └──────────┘ │  │ └──────────┘ │        │
│  └──────────────┘  └──────────────┘        │
└─────────────────────────────────────────────┘
```

**Purpose**: Multi-version PHP with per-user isolation
**Key Features**:
- Parallel PHP versions (7.4, 8.1, 8.2)
- Separate FPM pool per user per PHP version
- Unix socket communication
- Per-user session and cache directories
- Resource limits per pool
- OPcache configuration

**Pool Configuration**:
```
/etc/opt/remi/php82/php-fpm.d/
├── username1.conf
├── username2.conf
└── ...

Sockets:
/var/opt/remi/php82/run/php-fpm/
├── username1.sock
├── username2.sock
└── ...
```

### Layer 4: Data Layer (mariadb)
```
┌─────────────────────────────────────────┐
│          MariaDB Server                 │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │    Database per Domain          │   │
│  │                                 │   │
│  │  user1_example_com              │   │
│  │  user1_blog_example_com         │   │
│  │  user2_clientsite_com           │   │
│  │  ...                            │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  User per Database (scoped)     │   │
│  │                                 │   │
│  │  user1_example_com → user1_db   │   │
│  │  user1_blog... → user1_blog_db  │   │
│  │  ...                            │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Purpose**: Automated database provisioning with security
**Key Features**:
- Auto-generated strong passwords
- Database per domain/subdomain
- Scoped database user privileges
- Automated credential delivery
- Performance optimization
- UTF-8MB4 support

## Data Flow

### Request Processing Flow

```
1. Browser Request
   ↓
2. DNS Resolution → Server IP
   ↓
3. Apache HTTPD (Port 80/443)
   ↓
4. VirtualHost Matching
   │
   ├─→ Static Content → Serve directly
   │
   └─→ PHP Request
       ↓
5. Proxy to PHP-FPM Unix Socket
   ↓
6. PHP-FPM Pool (User-specific)
   │
   ├─→ Execute PHP Code
   ├─→ Access User Files
   └─→ Connect to MariaDB (if needed)
       ↓
7. Database Query
   ↓
8. Response back through chain
   ↓
9. Apache → Browser
```

## Security Architecture

### Multi-Layer Security Model

```
┌────────────────────────────────────────────────┐
│  Layer 5: Network Firewall                    │
│  ► HTTP/HTTPS only                            │
│  ► SSH on non-standard port (optional)        │
└────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────┐
│  Layer 4: SELinux                              │
│  ► Mandatory Access Control                   │
│  ► httpd_sys_content_t contexts               │
│  ► httpd_can_network_connect boolean          │
└────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────┐
│  Layer 3: File System Permissions & ACLs      │
│  ► User ownership                             │
│  ► Apache read-only ACL                       │
│  ► 0600 for sensitive files                   │
└────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────┐
│  Layer 2: Process Isolation                   │
│  ► PHP-FPM pools run as user                  │
│  ► Open_basedir restrictions                  │
│  ► Disabled dangerous functions               │
└────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────┐
│  Layer 1: Database Security                   │
│  ► Scoped privileges                          │
│  ► Localhost-only connections                 │
│  ► Strong auto-generated passwords            │
└────────────────────────────────────────────────┘
```

## Scalability Considerations

### Horizontal Scaling
```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Web01      │    │   Web02      │    │   Web03      │
│  (Frontend)  │    │  (Frontend)  │    │  (Frontend)  │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       └───────────────────┴───────────────────┘
                           │
                ┌──────────▼────────────┐
                │   Load Balancer       │
                │   (HAProxy/Nginx)     │
                └──────────┬────────────┘
                           │
                ┌──────────▼────────────┐
                │   Shared Storage      │
                │   (NFS/GlusterFS)     │
                └───────────────────────┘
                           │
                ┌──────────▼────────────┐
                │   MariaDB Cluster     │
                │   (Galera)            │
                └───────────────────────┘
```

### Vertical Scaling
- **Apache**: Increase MaxRequestWorkers
- **PHP-FPM**: Increase max_children per pool
- **MariaDB**: Increase buffer pool size
- **Hardware**: More RAM, faster disks, better CPU

## Performance Optimization Strategy

### 1. Caching Layers
```
Browser Cache
    ↓
CDN (CloudFlare)
    ↓
Varnish/Nginx Cache
    ↓
Apache (mod_cache_disk)
    ↓
OPcache (PHP)
    ↓
Query Cache (MariaDB)
    ↓
Application Cache (Redis/Memcached)
```

### 2. Resource Management

**PHP-FPM Pool Sizing Formula**:
```
max_children = (Available RAM - System RAM) / Average Process Size

Example:
Server RAM: 16GB
System RAM: 4GB
PHP Process: ~128MB

max_children = (16GB - 4GB) / 128MB = 96 processes
Safety margin: 80 processes
```

**MariaDB Buffer Pool**:
```
innodb_buffer_pool_size = 50-70% of total RAM

Example:
Server RAM: 16GB
Buffer Pool: 10GB (62.5%)
```

## Disaster Recovery

### Backup Strategy
```
┌───────────────────────────────────────┐
│         Backup Hierarchy              │
├───────────────────────────────────────┤
│  Level 1: Real-time Replication      │
│  ► MariaDB Master-Slave              │
│  ► NFS Mirroring                     │
├───────────────────────────────────────┤
│  Level 2: Hourly Backups             │
│  ► Incremental DB dumps              │
│  ► rsync snapshots                   │
├───────────────────────────────────────┤
│  Level 3: Daily Backups              │
│  ► Full DB dumps                     │
│  ► Complete tar archives             │
├───────────────────────────────────────┤
│  Level 4: Weekly Offsite             │
│  ► Cloud storage (S3/B2)             │
│  ► Geographic redundancy             │
└───────────────────────────────────────┘
```

### Recovery Time Objectives (RTO)
- **Configuration**: < 5 minutes
- **Database**: < 15 minutes
- **Full System**: < 1 hour

## Monitoring Architecture

### Metrics Collection
```
┌─────────────────────────────────────────┐
│  System Metrics (node_exporter)        │
│  ► CPU, Memory, Disk, Network          │
└────────────┬────────────────────────────┘
             │
┌────────────▼────────────────────────────┐
│  Service Metrics                        │
│  ► Apache (mod_status)                  │
│  ► PHP-FPM (status page)                │
│  ► MariaDB (mysqld_exporter)            │
└────────────┬────────────────────────────┘
             │
┌────────────▼────────────────────────────┐
│  Prometheus (Time Series DB)            │
│  ► Scrapes metrics every 15s            │
│  ► Stores with retention                │
└────────────┬────────────────────────────┘
             │
┌────────────▼────────────────────────────┐
│  Grafana (Visualization)                │
│  ► Real-time dashboards                 │
│  ► Alert management                     │
└─────────────────────────────────────────┘
```

## Future Enhancements

### Planned Features
- [ ] Automated SSL certificate management (Let's Encrypt)
- [ ] Built-in backup automation
- [ ] Redis/Memcached integration
- [ ] Email server integration (Postfix)
- [ ] FTP/SFTP user management
- [ ] Resource quota enforcement
- [ ] Web-based control panel
- [ ] Automated security scanning
- [ ] Container support (Docker/Podman)
- [ ] Kubernetes deployment option

### Integration Points
- **CI/CD**: Jenkins, GitLab CI, GitHub Actions
- **Monitoring**: Prometheus, Grafana, Nagios, Zabbix
- **Logging**: ELK Stack, Loki, Graylog
- **Backup**: Restic, Duplicity, BorgBackup
- **CDN**: CloudFlare, AWS CloudFront
- **DNS**: CloudFlare, Route53, PowerDNS

## Contributing Guidelines

### Development Workflow
1. Fork the repository
2. Create feature branch
3. Implement changes
4. Test in staging environment
5. Update documentation
6. Submit pull request

### Code Standards
- Follow Ansible best practices
- Use YAML lint
- Include comments for complex logic
- Update CHANGELOG.md
- Add tests where applicable

## Version History

### Version 1.0.0 (Current)
- Initial release
- Rocky Linux 9 support
- PHP 7.4, 8.1, 8.2
- Apache HTTPD
- MariaDB
- Complete documentation

---

**Project Status**: Production Ready  
**Maintained By**: DevOps Team  
**Last Updated**: February 2026  
**License**: MIT
