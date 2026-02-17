#!/bin/bash
# Pre-deployment validation script
# This script checks if your configuration is ready for deployment

set -e

echo "=========================================="
echo "Ansible Shared Hosting - Pre-Deploy Check"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    ERRORS=$((ERRORS + 1))
}

warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

info() {
    echo "ℹ $1"
}

# Check 1: Inventory file exists
echo "Checking inventory configuration..."
if [ -f "inventories/production.ini" ]; then
    success "Inventory file exists: inventories/production.ini"
    
    # Check if it has content
    if grep -q "\[webservers\]" inventories/production.ini; then
        success "Inventory has [webservers] group"
    else
        error "Inventory missing [webservers] group"
    fi
    
    # Check if it has hosts
    HOST_COUNT=$(grep -v "^\[" inventories/production.ini | grep -v "^#" | grep -v "^$" | grep -v "ansible_" | wc -l)
    if [ "$HOST_COUNT" -gt 0 ]; then
        success "Inventory has $HOST_COUNT host(s) defined"
    else
        error "No hosts defined in inventory"
    fi
else
    error "Inventory file not found: inventories/production.ini"
    info "  Copy from: inventories/production.ini.example"
fi
echo ""

# Check 2: Group vars file exists
echo "Checking group_vars configuration..."
if [ -f "group_vars/webservers.yml" ]; then
    success "Configuration file exists: group_vars/webservers.yml"
    
    # Check for hosting_users
    if grep -q "hosting_users:" group_vars/webservers.yml; then
        success "hosting_users variable is defined"
        
        # Check if it's not just commented
        if grep "^hosting_users:" group_vars/webservers.yml | grep -q "\[\]"; then
            warning "hosting_users is empty (no users will be created)"
        fi
    else
        error "hosting_users variable is NOT defined"
        info "  Add to group_vars/webservers.yml:"
        info "  hosting_users: []"
    fi
    
    # Check for mariadb_root_password
    if grep -q "mariadb_root_password:" group_vars/webservers.yml; then
        success "mariadb_root_password is defined"
        
        # Check if it's the default
        if grep "mariadb_root_password:" group_vars/webservers.yml | grep -q "ChangeMeToSecurePassword\|ChangeMe123"; then
            warning "Using default/weak MariaDB password - change it!"
        fi
    else
        error "mariadb_root_password is NOT defined"
        info "  Add to group_vars/webservers.yml:"
        info "  mariadb_root_password: 'YourSecurePassword123!'"
    fi
    
else
    error "Configuration file not found: group_vars/webservers.yml"
    info "  Copy from: group_vars/webservers.yml.example"
    info "  Or see example in README.md"
fi
echo ""

# Check 3: Ansible installed
echo "Checking Ansible installation..."
if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -n1)
    success "Ansible is installed: $ANSIBLE_VERSION"
else
    error "Ansible is not installed"
    info "  Install with: pip3 install ansible"
fi
echo ""

# Check 4: Required collections
echo "Checking Ansible collections..."
REQUIRED_COLLECTIONS=("community.mysql" "ansible.posix" "community.general")
for collection in "${REQUIRED_COLLECTIONS[@]}"; do
    if ansible-galaxy collection list | grep -q "$collection"; then
        success "Collection installed: $collection"
    else
        warning "Collection not installed: $collection"
        info "  Install with: ansible-galaxy collection install $collection"
    fi
done
echo ""

# Check 5: SSH connectivity (if inventory has hosts)
if [ -f "inventories/production.ini" ]; then
    echo "Testing SSH connectivity..."
    if command -v ansible &> /dev/null; then
        if ansible webservers -i inventories/production.ini -m ping &> /dev/null; then
            success "SSH connectivity test passed"
        else
            warning "SSH connectivity test failed"
            info "  Test manually with: ansible webservers -i inventories/production.ini -m ping"
        fi
    else
        info "Skipping connectivity test (Ansible not installed)"
    fi
    echo ""
fi

# Check 6: Validate YAML syntax
echo "Validating YAML syntax..."
if command -v python3 &> /dev/null; then
    if [ -f "group_vars/webservers.yml" ]; then
        if python3 -c "import yaml; yaml.safe_load(open('group_vars/webservers.yml'))" 2>/dev/null; then
            success "group_vars/webservers.yml has valid YAML syntax"
        else
            error "group_vars/webservers.yml has YAML syntax errors"
            python3 -c "import yaml; yaml.safe_load(open('group_vars/webservers.yml'))"
        fi
    fi
else
    info "Skipping YAML validation (Python3 not found)"
fi
echo ""

# Summary
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! You're ready to deploy.${NC}"
    echo ""
    echo "Next step:"
    echo "  ansible-playbook -i inventories/production.ini playbooks/site.yml"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found. You can proceed but review warnings.${NC}"
    echo ""
    echo "To deploy despite warnings:"
    echo "  ansible-playbook -i inventories/production.ini playbooks/site.yml"
    exit 0
else
    echo -e "${RED}✗ $ERRORS error(s) found. Fix errors before deploying.${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ $WARNINGS warning(s) found.${NC}"
    fi
    echo ""
    echo "For help, see:"
    echo "  - COMMON_ERRORS.md"
    echo "  - QUICKSTART.md"
    echo "  - README.md"
    exit 1
fi
