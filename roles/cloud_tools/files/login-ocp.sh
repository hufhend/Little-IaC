#!/bin/bash

#   ***********************************
#   OpenShift Cluster Manager
#   begin     : Tue 16 Dec 2025
#   copyright : (c) 2025 Václav Dvorský
#   email     : hufhendr@gmail.com
#   $Id: ocp-login.sh, v2.24 23/12/2025
#   ***********************************

#   --------------------------------------------------------------------
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public Licence as published by
#   the Free Software Foundation; either version 2 of the Licence, or
#   (at your option) any later version.
#   --------------------------------------------------------------------

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

CHECKMARK="${GREEN}✓${NC}"
CROSSMARK="${RED}✗${NC}"
WARNING="${YELLOW}⚠${NC}"
INFO="${BLUE}ℹ${NC}"

# Logging functions - IMPROVED FORMATTING
log_info() {
    echo -e "${INFO} ${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${CHECKMARK} ${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${WARNING} ${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${CROSSMARK} ${RED}[ERROR]${NC} $1"
}

# Function to print formatted info line
print_info() {
    local label=$1
    local value=$2
    local indent=${3:-4}
    
    printf "%${indent}s${BLUE}%-12s${NC} %s\n" "" "${label}:" "$value"
}

# Function to print formatted success line
print_success() {
    local label=$1
    local value=$2
    local indent=${3:-4}
    
    printf "%${indent}s${GREEN}%-12s${NC} %s\n" "" "${label}:" "$value"
}

# Validate configuration
validate_config() {
    # Backward compatibility: if OCP_CONTEXT exists, use it
    if [ -n "${OCP_CONTEXT}" ] && [ -z "${OCP_CONTEXT_PARSED}" ]; then
        OCP_CONTEXT_PARSED="${OCP_CONTEXT}"
        export OCP_CONTEXT_PARSED
    fi
    
    # Generate OCP_CONTEXT_PARSED if not set
    if [ -z "${OCP_CONTEXT_PARSED}" ] && [ -n "${OCP_CLUSTER_URL}" ]; then
        OCP_CONTEXT_PARSED=$(echo "${OCP_CLUSTER_URL}" | sed '
            s|https://api\.||
            s|https://||
            s|:6443||
            s|\.example\.com||
            s|\.com||
            s|\.cz||
            s|\.org||
            s|\.net||
            s|\.io||
            s|-cluster||
            s|\.|-|g
        ')
        export OCP_CONTEXT_PARSED
    fi
    
    local missing_vars=()
    
    if [ -z "${OCP_CLUSTER_URL}" ]; then
        missing_vars+=("OCP_CLUSTER_URL")
    fi
    
    if [ -z "${OCP_USERNAME}" ]; then
        missing_vars+=("OCP_USERNAME")
    fi
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required environment variables!"
        log_error "Set these in your ~/.bashrc or ~/.bash_aliases:"
        log_error "  export OCP_CLUSTER_URL='https://api.cluster.example.com:6443'"
        log_error "  export OCP_USERNAME='your-username'"
        log_error "  export OCP_CONTEXT='your-context-name'  (optional, for login logic)"
        return 1
    fi
    
    return 0
}

# Check login status
check_oc_login() {
    echo
    log_info "Checking cluster login status..."
    
    # Check if oc tool is available
    if ! command -v oc &> /dev/null; then
        log_error "OpenShift CLI (oc) not found!"
        log_error "Install with: brew install openshift-cli  # for macOS"
        log_error "or download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
        exit 1
    fi

    # Validate configuration first
    if ! validate_config; then
        return 1
    fi

    # Check if we're logged in using whoami
    if ! oc whoami &> /dev/null; then
        return 1
    fi

    # Get current user
    CURRENT_USER=$(oc whoami 2>/dev/null)
    if [ -n "${CURRENT_USER}" ]; then
        log_success "Logged in as: ${CURRENT_USER}"

        # Get current context
        CURRENT_CONTEXT=$(oc config current-context 2>/dev/null)
        if [ -n "${CURRENT_CONTEXT}" ]; then
            log_success "Current context: ${CURRENT_CONTEXT}"

            # Check if we're in the right context
            if [ -n "${OCP_CONTEXT}" ] && [ "${CURRENT_CONTEXT}" = "${OCP_CONTEXT}" ]; then
                log_success "Context matches: ${OCP_CONTEXT}"
            elif [ -n "${OCP_CONTEXT}" ]; then
                log_warn "⚠ Context doesn't match"
                log_warn "  Expected: ${OCP_CONTEXT}"
                log_warn "  Current:  ${CURRENT_CONTEXT}"
                return 3
            else
                log_info "OCP_CONTEXT not set, skipping context validation"
            fi

            # Try to get current project (if we have permissions)
            if CURRENT_PROJECT=$(oc project -q 2>/dev/null); then
                log_success "Current project: ${CURRENT_PROJECT}"
            else
                log_warn "Cannot load current project - limited permissions"
            fi

            # Test basic permissions
            if oc get nodes --request-timeout=5s &> /dev/null; then
                log_success "You have valid cluster permissions"
                return 0
            else
                log_warn "You have limited permissions in the cluster"
                return 2
            fi
        fi
    fi
    
    return 1
}

# Clean up old configs
cleanup_old_config() {
    log_info "Cleaning up old configuration..."

    # Remove old context if it exists
    local context_to_clean="${OCP_CONTEXT:-${OCP_CONTEXT_PARSED}}"
    
    if [ -n "${context_to_clean}" ] && oc config get-contexts "${context_to_clean}" &> /dev/null; then
        oc config delete-context "${context_to_clean}"
        log_info "Old context '${context_to_clean}' removed"
    fi

    # Logout if we're logged in
    if oc whoami &> /dev/null; then
        oc logout
        log_info "Logged out from old session"
    fi
}

# Setup context after login
setup_context() {
    local context_to_setup="${OCP_CONTEXT:-${OCP_CONTEXT_PARSED}}"
    
    log_info "Setting up context: ${context_to_setup}"
    
    # Get current cluster and user from oc config
    CURRENT_CLUSTER=$(oc config view --minify -o jsonpath='{.contexts[0].context.cluster}' 2>/dev/null)
    CURRENT_USER=$(oc config view --minify -o jsonpath='{.contexts[0].context.user}' 2>/dev/null)
    
    if [ -z "${CURRENT_CLUSTER}" ] || [ -z "${CURRENT_USER}" ]; then
        log_warn "Could not extract cluster/user info, using current context"
        CURRENT_CONTEXT=$(oc config current-context 2>/dev/null)
        oc config rename-context "${CURRENT_CONTEXT}" "${context_to_setup}" 2>/dev/null
    else
        # Create or update the context
        oc config set-context "${context_to_setup}" \
            --cluster="${CURRENT_CLUSTER}" \
            --user="${CURRENT_USER}" \
            --namespace=default 2>/dev/null
    fi
    
    # Switch to our context
    oc config use-context "${context_to_setup}" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_success "Context '${context_to_setup}' configured and activated"
        return 0
    else
        log_error "Failed to setup context '${context_to_setup}'"
        return 1
    fi
}

# Main login function
login_to_cluster() {
    # Validate configuration
    if ! validate_config; then
        return 1
    fi
    
    echo -e "${GREEN}┌───────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│                  OpenShift Login                  │${NC}"
    echo -e "${GREEN}└───────────────────────────────────────────────────┘${NC}"
    echo
    print_info "Cluster" "${OCP_CLUSTER_URL}"
    print_info "Username" "${OCP_USERNAME}"
    
    # Zobrazujeme OCP_CONTEXT_PARSED
    if [ -n "${OCP_CONTEXT_PARSED}" ]; then
        print_info "Profile" "${OCP_CONTEXT_PARSED}"
    elif [ -n "${OCP_CONTEXT}" ]; then
        print_info "Context" "${OCP_CONTEXT}"
    fi
    echo

    # Warning about insecure TLS
    log_warn "Using insecure TLS verification (--insecure-skip-tls-verify)"
    log_warn "This should only be used in trusted environments!"
    echo

    # Clean up old configuration
    cleanup_old_config

    # Start login
    oc login "${OCP_CLUSTER_URL}" -u "${OCP_USERNAME}" --insecure-skip-tls-verify=true

    # Check login success
    if [ $? -eq 0 ]; then
        echo
        echo -e "${CHECKMARK} ${GREEN}Login successful!${NC}"

        # Setup our context
        setup_context

        # Short pause for stabilization
        sleep 1

        # Verify login again
        if oc whoami &> /dev/null; then
            CURRENT_USER=$(oc whoami)
            log_success "User: ${CURRENT_USER}"

            # Set namespace to default if possible
            oc project default 2>/dev/null || true

            # Get current context
            CURRENT_CONTEXT=$(oc config current-context)
            log_success "Active context: ${CURRENT_CONTEXT}"

            # Test cluster connection - IMPROVED OUTPUT
            echo
            log_info "Testing cluster connection..."
            if timeout 10s oc get nodes --no-headers 2>/dev/null | head -5; then
                local node_count=$(oc get nodes --no-headers 2>/dev/null | wc -l)
                local ready_nodes=$(oc get nodes --no-headers 2>/dev/null | grep -c "Ready")
                echo -e "${CHECKMARK} ${GREEN}[SUCCESS]${NC} Cluster responding, nodes: ${ready_nodes}/${node_count} ready"
            else
                log_warn "Cluster not responding or limited permissions"
                log_info "Try: oc get projects  # to see available projects"
            fi

            # Show oc version
            echo
            log_info "OpenShift CLI version:"
            oc version 2>/dev/null | grep -E "(Client Version:|openshift)" || true

            return 0
        else
            log_error "Login failed - cannot verify user"
            return 1
        fi
    else
        log_error "Login failed!"
        return 1
    fi
}

# Quick login version (non-interactive)
quick_login() {
    # Validate configuration
    if ! validate_config; then
        return 1
    fi
    
    echo "Logging into ${OCP_CLUSTER_URL}..."
    
    if [ -n "${OCP_CONTEXT_PARSED}" ]; then
        echo "Using profile: ${OCP_CONTEXT_PARSED}"
    elif [ -n "${OCP_CONTEXT}" ]; then
        echo "Using context: ${OCP_CONTEXT}"
    fi
    
    # Logout if already logged in
    oc logout 2>/dev/null
    
    # Login
    oc login "${OCP_CLUSTER_URL}" -u "${OCP_USERNAME}" --insecure-skip-tls-verify=true
    
    if [ $? -eq 0 ]; then
        echo -e "${CHECKMARK} ${GREEN}Logged in as:$(tput sgr0) $(oc whoami)"
        
        # Setup context
        CURRENT_CLUSTER=$(oc config view --minify -o jsonpath='{.contexts[0].context.cluster}' 2>/dev/null)
        CURRENT_USER=$(oc config view --minify -o jsonpath='{.contexts[0].context.user}' 2>/dev/null)
        
        local context_to_setup="${OCP_CONTEXT:-${OCP_CONTEXT_PARSED}}"
        
        if [ -n "${context_to_setup}" ] && [ -n "${CURRENT_CLUSTER}" ] && [ -n "${CURRENT_USER}" ]; then
            oc config set-context "${context_to_setup}" \
                --cluster="${CURRENT_CLUSTER}" \
                --user="${CURRENT_USER}" \
                --namespace=default 2>/dev/null
            oc config use-context "${context_to_setup}" 2>/dev/null
            echo -e "${CHECKMARK} ${GREEN}Context set to:$(tput sgr0) ${context_to_setup}"
        else
            echo "✓ Using current context: $(oc config current-context)"
        fi
    else
        echo "✗ Login failed"
        return 1
    fi
}

# Status check only
status_check() {
    echo -e "${INFO} Checking OpenShift cluster status..."
    echo
    
    if ! command -v oc &> /dev/null; then
        echo -e "${CROSSMARK} ${RED}[ERROR]${NC} OpenShift CLI (oc) not found!"
        exit 1
    fi
    
    if oc whoami &> /dev/null; then
        echo -e "${CHECKMARK} OpenShift cluster connected"
        echo
        
        print_success "User" "$(oc whoami 2>/dev/null)"
        print_success "Context" "$(oc config current-context 2>/dev/null)"
        
        if CURRENT_PROJECT=$(oc project -q 2>/dev/null); then
            print_success "Project" "${CURRENT_PROJECT}"
        fi
        
        # Get node info
        if oc get nodes --request-timeout=5s &> /dev/null; then
            local node_count=$(oc get nodes --no-headers 2>/dev/null | wc -l)
            local ready_nodes=$(oc get nodes --no-headers 2>/dev/null | grep -c "Ready")
            print_success "Nodes" "${ready_nodes}/${node_count} ready"
        fi
        
        exit 0
    else
        echo -e "${CROSSMARK} ${RED}[ERROR]${NC} Not connected to OpenShift cluster"
        exit 1
    fi
}

# Show help
show_help() {
    echo -e "${CYAN}┌───────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│             OpenShift Cluster Manager             │${NC}"
    echo -e "${CYAN}└───────────────────────────────────────────────────┘${NC}"
    echo
    echo "Script for OpenShift cluster login and management"
    echo
    echo -e "${BLUE}Usage:${NC} $0 [OPTION]"
    echo
    echo -e "${YELLOW}Options:${NC}"
    echo "  -q, --quick      Quick login without interactive questions"
    echo "  -h, --help       Show this help message"
    echo "  --status         Check current login status only"
    echo "  --force, -f      Force login (skip status check)"
    echo
    echo -e "${GREEN}Environment variables:${NC}"
    echo "  OCP_CLUSTER_URL       Cluster API URL (REQUIRED)"
    echo "  OCP_USERNAME          OpenShift username (REQUIRED)"
    echo "  OCP_CONTEXT           Context name (for login logic, optional)"
    echo "  OCP_CONTEXT_PARSED    Display profile name (optional, display only)"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0               # Interactive login mode"
    echo "  $0 --quick       # Quick non-interactive login"
    echo "  $0 --status      # Check current login status"
    echo "  $0 --force       # Force login without asking"
    echo
    echo -e "${MAGENTA}Aliases in .bash_aliases:${NC}"
    echo "  alias ocl='ocp-login'                  # Interactive"
    echo "  alias oclq='ocp-login --quick'         # Quick login"
    echo "  alias ocls='ocp-login --status'.       # Status check"
}

# Main script
main() {
    # Check for help flag
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        exit 0
    fi
    
    # Check for status flag
    if [ "$1" = "--status" ]; then
        status_check
    fi
    
    # Check for force login flag
    if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
        login_to_cluster
        exit 0
    fi
    
    # Check for quick login flag
    if [ "$1" = "--quick" ] || [ "$1" = "-q" ]; then
        quick_login
        exit 0
    fi
    
    # Default interactive mode
    echo -e "${CYAN}┌───────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│                  Cluster Manager                  │${NC}"
    echo -e "${CYAN}└───────────────────────────────────────────────────┘${NC}"
    echo
    
    # Show cluster info
    print_info "Cluster" "${OCP_CLUSTER_URL}"
    print_info "Username" "${OCP_USERNAME}"
    
    # Display OCP_CONTEXT_PARSED if it exists, otherwise OCP_CONTEXT
    if [ -n "${OCP_CONTEXT_PARSED}" ]; then
        print_info "Profile" "${OCP_CONTEXT_PARSED}"
    elif [ -n "${OCP_CONTEXT}" ]; then
        print_info "Context" "${OCP_CONTEXT}"
    fi
    echo
    
    # Check current status
    if check_oc_login; then
        # Fixed: remove duplicate checkmark
        echo -e "${CHECKMARK} ${GREEN}Already logged in${NC}"
        echo
        
        read -p "Do you want to logout? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            oc logout
            echo -e "${CHECKMARK} ${GREEN}Logged out${NC}"
        else
            echo -e "${CHECKMARK} ${GREEN}Continuing with current session${NC}"
        fi
    else
        echo
        log_warn "You are not logged in or have invalid permissions."
        echo
        
        log_info "Available commands after login:"
        echo "  oc get pods              # Show running pods"
        echo "  oc get projects          # List projects"
        echo "  oc status                # Project status"
        echo "  oc whoami                # Show current user"
        echo "  oc logout                # Logout"
        echo
        
        read -p "Do you want to login to the cluster? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            login_to_cluster
        else
            log_info "Login cancelled by user."
        fi
    fi
}

# Run main function
main "$@"
