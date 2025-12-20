#!/bin/bash

#   ***********************************
#   OpenShift Login Script
#   begin     : Tue 16 Dec 2025
#   copyright : (c) 2025 Václav Dvorský
#   email     : hufhendr@gmail.com
#   $Id: login-ocp.sh, v1.22 18/12/2025
#   ***********************************

#   --------------------------------------------------------------------
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public Licence as published by
#   the Free Software Foundation; either version 2 of the Licence, or
#   (at your option) any later version.
#   --------------------------------------------------------------------

# Cluster variables - ALL MUST BE SET IN ENVIRONMENT
CLUSTER_URL="${OCP_CLUSTER_URL}"
USERNAME="${OCP_USERNAME}"
CONTEXT_NAME="${OCP_CONTEXT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to validate configuration
validate_config() {
    local missing_vars=()
    
    if [ -z "${CLUSTER_URL}" ]; then
        missing_vars+=("OCP_CLUSTER_URL")
    fi
    
    if [ -z "${USERNAME}" ]; then
        missing_vars+=("OCP_USERNAME")
    fi
    
    if [ -z "${CONTEXT_NAME}" ]; then
        missing_vars+=("OCP_CONTEXT")
    fi
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required environment variables!"
        log_error "Set these in your ~/.bashrc or ~/.bash_aliases:"
        log_error "  export OCP_CLUSTER_URL='https://api.cluster.example.com:6443'"
        log_error "  export OCP_USERNAME='your-username'"
        log_error "  export OCP_CONTEXT='your-context-name'"
        return 1
    fi
    
    return 0
}

# Function to check login status
check_oc_login() {
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
        log_warn "You are not logged in or token has expired"
        return 1
    fi

    # Get current user
    CURRENT_USER=$(oc whoami 2>/dev/null)
    if [ -n "${CURRENT_USER}" ]; then
        log_success "Logged in as: ${CURRENT_USER}"

        # Get current context
        CURRENT_CONTEXT=$(oc config current-context 2>/dev/null)
        if [ -n "${CURRENT_CONTEXT}" ]; then
            log_success "Active context: ${CURRENT_CONTEXT}"

            # Check if we're in the right context
            if [ "${CURRENT_CONTEXT}" = "${CONTEXT_NAME}" ]; then
                log_success "✓ Context matches: ${CONTEXT_NAME}"
            else
                log_warn "⚠ Context doesn't match"
                log_warn "  Expected: ${CONTEXT_NAME}"
                log_warn "  Current:  ${CURRENT_CONTEXT}"
                return 3
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

# Function to clean up old configs
cleanup_old_config() {
    log_info "Cleaning up old configuration..."

    # Remove old context if it exists
    if oc config get-contexts "${CONTEXT_NAME}" &> /dev/null; then
        oc config delete-context "${CONTEXT_NAME}"
        log_info "Old context '${CONTEXT_NAME}' removed"
    fi

    # Logout if we're logged in
    if oc whoami &> /dev/null; then
        oc logout
        log_info "Logged out from old session"
    fi
}

# Function to setup context after login
setup_context() {
    log_info "Setting up context: ${CONTEXT_NAME}"
    
    # Get current cluster and user from oc config
    CURRENT_CLUSTER=$(oc config view --minify -o jsonpath='{.contexts[0].context.cluster}' 2>/dev/null)
    CURRENT_USER=$(oc config view --minify -o jsonpath='{.contexts[0].context.user}' 2>/dev/null)
    
    if [ -z "${CURRENT_CLUSTER}" ] || [ -z "${CURRENT_USER}" ]; then
        log_warn "Could not extract cluster/user info, using current context"
        CURRENT_CONTEXT=$(oc config current-context 2>/dev/null)
        oc config rename-context "${CURRENT_CONTEXT}" "${CONTEXT_NAME}" 2>/dev/null
    else
        # Create or update the context
        oc config set-context "${CONTEXT_NAME}" \
            --cluster="${CURRENT_CLUSTER}" \
            --user="${CURRENT_USER}" \
            --namespace=default 2>/dev/null
    fi
    
    # Switch to our context
    oc config use-context "${CONTEXT_NAME}" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_success "Context '${CONTEXT_NAME}' configured and activated"
        return 0
    else
        log_error "Failed to setup context '${CONTEXT_NAME}'"
        return 1
    fi
}

# Main login function
login_to_cluster() {
    # Validate configuration
    if ! validate_config; then
        return 1
    fi
    
    echo -e "${GREEN}┌────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│ OpenShift Cluster Login                            │${NC}"
    echo -e "${GREEN}│ Cluster: ${CLUSTER_URL}${NC}"
    echo -e "${GREEN}│ Username: ${USERNAME}${NC}"
    echo -e "${GREEN}│ Context: ${CONTEXT_NAME}${NC}"
    echo -e "${GREEN}└────────────────────────────────────────────────────┘${NC}"
    echo

    # Warning about insecure TLS
    log_warn "Using insecure TLS verification (--insecure-skip-tls-verify)"
    log_warn "This should only be used in trusted environments!"
    echo

    # Clean up old configuration
    cleanup_old_config

    # Start login
    oc login "${CLUSTER_URL}" -u "${USERNAME}" --insecure-skip-tls-verify=true

    # Check login success
    if [ $? -eq 0 ]; then
        log_success "Login successful!"

        # Setup our context
        setup_context

        # Short pause for stabilization
        sleep 2

        # Verify login again
        if oc whoami &> /dev/null; then
            CURRENT_USER=$(oc whoami)
            log_success "User: ${CURRENT_USER}"

            # Set namespace to default if possible
            oc project default 2>/dev/null || true

            # Get current context
            CURRENT_CONTEXT=$(oc config current-context)
            log_success "Active context: ${CURRENT_CONTEXT}"

            # Test cluster connection
            echo
            log_info "Testing cluster connection..."
            if timeout 10s oc get nodes --no-headers 2>/dev/null | head -5; then
                NODE_COUNT=$(oc get nodes --no-headers 2>/dev/null | wc -l)
                echo -e "${GREEN}[SUCCESS]${NC} Cluster responding, node count: ${NODE_COUNT}"
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

# Simplified version for quick use
quick_login() {
    # Validate configuration
    if ! validate_config; then
        return 1
    fi
    
    echo "Logging into ${CLUSTER_URL}..."
    echo "Using context: ${CONTEXT_NAME}"
    
    # Logout if already logged in
    oc logout 2>/dev/null
    
    # Login
    oc login "${CLUSTER_URL}" -u "${USERNAME}" --insecure-skip-tls-verify=true
    
    if [ $? -eq 0 ]; then
        echo "✓ Logged in as: $(oc whoami)"
        
        # Setup context
        CURRENT_CLUSTER=$(oc config view --minify -o jsonpath='{.contexts[0].context.cluster}' 2>/dev/null)
        CURRENT_USER=$(oc config view --minify -o jsonpath='{.contexts[0].context.user}' 2>/dev/null)
        
        if [ -n "${CURRENT_CLUSTER}" ] && [ -n "${CURRENT_USER}" ]; then
            oc config set-context "${CONTEXT_NAME}" \
                --cluster="${CURRENT_CLUSTER}" \
                --user="${CURRENT_USER}" \
                --namespace=default 2>/dev/null
            oc config use-context "${CONTEXT_NAME}" 2>/dev/null
            echo "✓ Context set to: ${CONTEXT_NAME}"
        else
            echo "✓ Using current context: $(oc config current-context)"
        fi
    else
        echo "✗ Login failed"
        return 1
    fi
}

# Show help
show_help() {
    echo "OpenShift Cluster Login Script"
    echo "Usage: $0 [OPTION]"
    echo
    echo "Options:"
    echo "  -q, --quick      Quick login without interactive questions"
    echo "  -h, --help       Show this help message"
    echo "  --status         Check current login status only"
    echo "  --force, -f      Force login (skip status check)"
    echo
    echo "Environment variables (REQUIRED - set in ~/.bashrc or ~/.bash_aliases):"
    echo "  OCP_CLUSTER_URL  Cluster API URL (e.g., https://api.cluster.example.com:6443)"
    echo "  OCP_USERNAME     OpenShift username"
    echo "  OCP_CONTEXT      Context name (e.g., 'my-prod-cluster', 'dev-env', etc.)"
    echo
    echo "Examples:"
    echo "  $0               Interactive login mode"
    echo "  $0 --quick       Quick non-interactive login"
    echo "  $0 --status      Check current login status"
    echo "  $0 --force       Force login without asking"
    echo
    echo "Installation:"
    echo "  sudo install $0 /usr/local/bin/ocp-login"
    echo "  chmod +x /usr/local/bin/ocp-login"
    echo
    echo "Example ~/.bash_aliases configuration:"
    echo "  export OCP_CLUSTER_URL='https://api.cluster.example.com:6443'"
    echo "  export OCP_USERNAME='jan.novak'"
    echo "  export OCP_CONTEXT='production-cluster'"
}

# Check status only
check_status() {
    if check_oc_login; then
        log_success "✓ You are logged in with valid permissions"
        log_info "Cluster: ${CLUSTER_URL}"
        log_info "Context: ${CONTEXT_NAME}"
        exit 0
    else
        log_error "✗ You are not logged in or have invalid permissions"
        exit 1
    fi
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
        check_status
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
    
    echo -e "${BLUE}=== OpenShift Cluster Manager ===${NC}"
    echo
    log_info "Cluster: ${CLUSTER_URL}"
    log_info "Username: ${USERNAME}"
    log_info "Context: ${CONTEXT_NAME}"
    echo
    
    # Check current status
    if check_oc_login; then
        log_success "You are logged in with valid permissions."
        echo
        log_info "Available commands:"
        echo "  oc get pods              # Show running pods"
        echo "  oc get projects          # List projects"
        echo "  oc status                # Project status"
        echo "  oc whoami                # Show current user"
        echo "  oc logout                # Logout"
        echo
        read -p "Do you want to logout? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            oc logout
            log_success "Logged out"
        fi
    else
        log_warn "You are not logged in or have invalid permissions."
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