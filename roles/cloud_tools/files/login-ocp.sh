#!/bin/bash

#   ************************************
#   Kubernetes/OpenShift Cluster Manager
#   begin     : Tue 16 Dec 2025
#   copyright : (c) 2025 Václav Dvorský
#   email     : hufhendr@gmail.com
#   $Id: ocp-login.sh, v2.11 22/12/2025
#   ************************************

#   --------------------------------------------------------------------
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public Licence as published by
#   the Free Software Foundation; either version 2 of the Licence, or
#   (at your option) any later version.
#   --------------------------------------------------------------------

# Colors and symbols
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

CHECKMARK="${GREEN}✓${NC}"
CROSSMARK="${RED}✗${NC}"
WARNING="${YELLOW}⚠${NC}"
INFO="${BLUE}ℹ${NC}"
SUCCESS="${GREEN}✔${NC}"

# Logging functions
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

log_debug() {
    if [ "${DEBUG}" = "true" ]; then
        echo -e "🔍 ${CYAN}[DEBUG]${NC} $1"
    fi
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

# Function to detect cluster type
detect_cluster_type() {
    local mode=$1
    
    # Priority 1: Check environment variables
    if [ -n "${OCP_CLUSTER_URL}" ] && [ -n "${OCP_USERNAME}" ]; then
        echo "openshift"
        return 0
    fi
    
    # Priority 2: Check if we're trying to use OpenShift login
    if [ "${mode}" = "force" ] || [ "${mode}" = "quick" ]; then
        echo "openshift"
        return 0
    fi
    
    # Priority 3: Check if we have active OpenShift session
    if command -v oc &> /dev/null; then
        if oc whoami --show-server &> /dev/null; then
            # We have an active OpenShift session
            echo "openshift"
            return 0
        fi
    fi
    
    # Priority 4: Default to Kubernetes
    echo "kubernetes"
}

# Function to get current CLI tool
get_cli_tool() {
    local cluster_type=$1
    
    if [ "${cluster_type}" = "openshift" ]; then
        # Check for oc
        if command -v oc &> /dev/null; then
            echo "oc"
        else
            log_error "OpenShift CLI (oc) not found!"
            return 1
        fi
    else
        # Check for kubectl
        if command -v kubectl &> /dev/null; then
            echo "kubectl"
        else
            log_error "Kubernetes CLI (kubectl) not found!"
            return 1
        fi
    fi
}

# Function to validate OpenShift configuration (only for OpenShift mode)
validate_openshift_config() {
    local missing_vars=()
    
    if [ -z "${OCP_CLUSTER_URL}" ]; then
        missing_vars+=("OCP_CLUSTER_URL")
    fi
    
    if [ -z "${OCP_USERNAME}" ]; then
        missing_vars+=("OCP_USERNAME")
    fi
    
    if [ -z "${OCP_CONTEXT}" ]; then
        # Try to generate context name from URL
        if [ -n "${OCP_CLUSTER_URL}" ]; then
            # Generic domain removal - no hardcoded domains
            OCP_CONTEXT=$(echo "${OCP_CLUSTER_URL}" | sed '
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
            export OCP_CONTEXT
            log_debug "Auto-generated context name: ${OCP_CONTEXT}"
        else
            missing_vars+=("OCP_CONTEXT")
        fi
    fi
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required OpenShift environment variables!"
        log_error "Set these in your ~/.bashrc or ~/.bash_aliases:"
        log_error "  export OCP_CLUSTER_URL='https://api.cluster.example.com:6443'"
        log_error "  export OCP_USERNAME='your-username'"
        log_error "  export OCP_CONTEXT='your-context-name'  (optional, auto-generated)"
        return 1
    fi
    
    return 0
}

# Function to check if we're logged in to OpenShift
check_openshift_login() {
    if ! command -v oc &> /dev/null; then
        return 1
    fi
    
    # Check if we can get user info
    if oc whoami &> /dev/null; then
        return 0
    fi
    
    return 1
}

# Function to check if current cluster is actually OpenShift
is_openshift_cluster() {
    local cli_tool=$1
    
    # First check if we're logged in
    if [ "${cli_tool}" = "oc" ]; then
        if ! check_openshift_login; then
            return 1
        fi
    fi
    
    # Check for OpenShift specific API resources
    if ${cli_tool} api-resources 2>/dev/null | grep -q "route.openshift.io"; then
        return 0  # It's OpenShift
    fi
    
    # Check for routes (OpenShift specific)
    if ${cli_tool} get routes --request-timeout=3s -A &> /dev/null; then
        return 0  # It's OpenShift
    fi
    
    # Check API version for OpenShift
    if ${cli_tool} version -o json 2>/dev/null | grep -qi "openshift"; then
        return 0  # It's OpenShift
    fi
    
    return 1  # It's not OpenShift
}

# Function to check if URL points to a real OpenShift cluster
is_valid_openshift_url() {
    local url=$1
    
    # Quick check if URL contains common OpenShift patterns
    if echo "${url}" | grep -qi "openshift\|ocp\|api\."; then
        return 0
    fi
    
    return 1
}

# Function to check cluster connection status
check_cluster_status() {
    local command_mode=$1
    local cluster_type=$(detect_cluster_type "${command_mode}")
    
    log_debug "Detected cluster type: ${cluster_type} (mode: ${command_mode})"
    
    local cli_tool=$(get_cli_tool "${cluster_type}")
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Now check if it's actually OpenShift
    local actual_cluster_type="kubernetes"
    if is_openshift_cluster "${cli_tool}"; then
        actual_cluster_type="openshift"
    fi
    
    log_info "Checking ${actual_cluster_type} cluster status..."
    
    if [ "${actual_cluster_type}" = "openshift" ]; then
        # OpenShift specific checks
        if ! check_openshift_login; then
            log_warn "Not logged in to OpenShift cluster"
            return 1
        fi
        
        local current_user=$(oc whoami 2>/dev/null)
        local current_context=$(oc config current-context 2>/dev/null || echo "unknown")
        local current_project=$(oc project -q 2>/dev/null || echo "unknown")
        
        echo
        echo -e "${CHECKMARK} ${GREEN}OpenShift cluster connected${NC}"
        echo
        
        print_success "User" "${current_user}"
        print_success "Context" "${current_context}"
        print_success "Project" "${current_project}"
        
        # Test cluster access
        if oc get nodes --request-timeout=5s &> /dev/null; then
            local node_count=$(oc get nodes --no-headers 2>/dev/null | wc -l)
            print_success "Nodes" "${node_count} available"
        fi
        
        return 0
        
    else
        # Kubernetes specific checks
        # Try to get cluster info
        if ! ${cli_tool} cluster-info &> /dev/null; then
            log_warn "Cannot connect to Kubernetes cluster"
            return 1
        fi
        
        local current_context=$(${cli_tool} config current-context 2>/dev/null || echo "unknown")
        local kubeconfig="${KUBECONFIG:-~/.kube/config}"
        
        echo
        echo -e "${CHECKMARK} ${GREEN}Kubernetes cluster connected${NC}"
        echo
        
        print_success "Context" "${current_context}"
        print_success "Kubeconfig" "${kubeconfig}"
        
        # Get additional info if available
        if ${cli_tool} get nodes --request-timeout=5s &> /dev/null; then
            local node_count=$(${cli_tool} get nodes --no-headers 2>/dev/null | wc -l)
            local ready_nodes=$(${cli_tool} get nodes --no-headers 2>/dev/null | grep -c "Ready")
            print_success "Nodes" "${ready_nodes}/${node_count} ready"
        fi
        
        # Get current namespace if available
        local current_namespace=$(${cli_tool} config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo "default")
        print_success "Namespace" "${current_namespace}"
        
        return 0
    fi
}

# Function to login to OpenShift cluster
login_openshift() {
    local quick_mode=$1
    
    if ! validate_openshift_config; then
        return 1
    fi
    
    local cluster_url="${OCP_CLUSTER_URL}"
    local username="${OCP_USERNAME}"
    local context_name="${OCP_CONTEXT}"
    
    # Check if this looks like a real OpenShift cluster URL
    if ! is_valid_openshift_url "${cluster_url}"; then
        log_warn "URL '${cluster_url}' doesn't look like an OpenShift cluster"
        log_warn "OpenShift clusters typically use 'https://api.' prefix"
        echo
    fi
    
    if [ "${quick_mode}" = "true" ]; then
        echo -e "${INFO} Logging into ${cluster_url}..."
        
        # Logout from any existing session
        oc logout 2>/dev/null
        
        # Login with insecure TLS (as in original script)
        oc login "${cluster_url}" -u "${username}" --insecure-skip-tls-verify=true
        
        if [ $? -eq 0 ]; then
            echo -e "${CHECKMARK} ${GREEN}Logged in as:$(tput sgr0) $(oc whoami)"
            
            # Setup context
            local current_cluster=$(oc config view --minify -o jsonpath='{.contexts[0].context.cluster}' 2>/dev/null)
            local current_user=$(oc config view --minify -o jsonpath='{.contexts[0].context.user}' 2>/dev/null)
            
            if [ -n "${current_cluster}" ] && [ -n "${current_user}" ]; then
                oc config set-context "${context_name}" \
                    --cluster="${current_cluster}" \
                    --user="${current_user}" \
                    --namespace=default 2>/dev/null
                oc config use-context "${context_name}" 2>/dev/null
                echo -e "${CHECKMARK} ${GREEN}Context set to:$(tput sgr0) ${context_name}"
            fi
        else
            log_error "Login failed"
            log_error "This might not be an OpenShift cluster"
            log_error "For Kubernetes clusters, use kubeconfig instead"
            return 1
        fi
        
    else
        # Interactive login
        echo -e "${GREEN}┌───────────────────────────────────────────────────┐${NC}"
        echo -e "${GREEN}│                  OpenShift Login                  │${NC}"
        echo -e "${GREEN}└───────────────────────────────────────────────────┘${NC}"
        echo
        print_info "Cluster" "${cluster_url}"
        print_info "Username" "${username}"
        print_info "Context" "${context_name}"
        echo
        
        log_warn "Using insecure TLS verification (--insecure-skip-tls-verify)"
        log_warn "This should only be used in trusted environments!"
        echo
        
        # Clean up old configuration
        if oc config get-contexts "${context_name}" &> /dev/null; then
            oc config delete-context "${context_name}" 2>/dev/null
            log_info "Removed old context: ${context_name}"
        fi
        
        if oc whoami &> /dev/null; then
            oc logout 2>/dev/null
            log_info "Logged out from old session"
        fi
        
        # Start login
        oc login "${cluster_url}" -u "${username}" --insecure-skip-tls-verify=true
        
        if [ $? -eq 0 ]; then
            echo
            echo -e "${CHECKMARK} ${GREEN}Login successful!${NC}"
            
            # Setup context
            local current_cluster=$(oc config view --minify -o jsonpath='{.contexts[0].context.cluster}' 2>/dev/null)
            local current_user=$(oc config view --minify -o jsonpath='{.contexts[0].context.user}' 2>/dev/null)
            
            if [ -n "${current_cluster}" ] && [ -n "${current_user}" ]; then
                oc config set-context "${context_name}" \
                    --cluster="${current_cluster}" \
                    --user="${current_user}" \
                    --namespace=default 2>/dev/null
                oc config use-context "${context_name}" 2>/dev/null
                echo
                echo -e "${CHECKMARK} ${GREEN}Context configured:${NC}"
                print_success "Name" "${context_name}"
                print_success "Cluster" "${current_cluster}"
                print_success "User" "${current_user}"
            fi
            
            # Show cluster info
            echo
            log_info "Cluster information:"
            print_success "User" "$(oc whoami)"
            print_success "Context" "$(oc config current-context)"
            
            # Test connection
            if oc get nodes --request-timeout=5s &> /dev/null; then
                local node_count=$(oc get nodes --no-headers 2>/dev/null | wc -l)
                print_success "Status" "Cluster responding"
                print_success "Nodes" "${node_count} available"
            fi
            
        else
            log_error "Login failed!"
            log_error "Check if this is really an OpenShift cluster"
            log_error "For Kubernetes, use kubeconfig files instead"
            return 1
        fi
    fi
    
    return 0
}

# Function to handle Kubernetes clusters (no login needed, just validation)
handle_kubernetes() {
    local kubeconfig="${KUBECONFIG:-~/.kube/config}"
    
    log_info "Kubernetes cluster mode"
    print_info "Kubeconfig" "${kubeconfig}"
    
    if [ ! -f "${kubeconfig}" ] && [ ! -f "${HOME}/.kube/config" ]; then
        log_error "No kubeconfig file found!"
        log_error "Set KUBECONFIG environment variable or create ~/.kube/config"
        return 1
    fi
    
    # Test connection
    if kubectl cluster-info &> /dev/null; then
        echo
        echo -e "${CHECKMARK} ${GREEN}Kubernetes cluster is accessible${NC}"
        
        local current_context=$(kubectl config current-context 2>/dev/null || echo "unknown")
        local current_namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo "default")
        
        echo
        log_info "Current configuration:"
        print_success "Context" "${current_context}"
        print_success "Namespace" "${current_namespace}"
        print_success "Config" "${kubeconfig}"
        
        # Show basic cluster info
        echo
        kubectl cluster-info | head -2 | while read line; do
            print_info "" "${line}" 2
        done
        
    else
        log_error "Cannot connect to Kubernetes cluster"
        log_error "Check your kubeconfig file and network connectivity"
        return 1
    fi
    
    return 0
}

# Function to prevent quick/force on Kubernetes clusters
prevent_k8s_quick_force() {
    if [ -n "${KUBECONFIG}" ] && [ -z "${OCP_CLUSTER_URL}" ]; then
        log_error "Quick/Force login is only for OpenShift clusters!"
        log_error ""
        log_error "You seem to be using a Kubernetes cluster (KUBECONFIG is set)"
        log_error "For Kubernetes clusters, use:"
        log_error "  ocls           # Check status"
        log_error "  kubectl ...    # Direct commands"
        log_error ""
        log_error "For OpenShift, set OCP_CLUSTER_URL and OCP_USERNAME first"
        return 1
    fi
    return 0
}

# Show help with better formatting
show_help() {
    echo -e "${CYAN}┌───────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│      Kubernetes / OpenShift Cluster Manager       │${NC}"
    echo -e "${CYAN}└───────────────────────────────────────────────────┘${NC}"
    echo
    echo "Universal script supporting both OpenShift and pure Kubernetes clusters"
    echo
    echo -e "${BLUE}Usage:${NC} $0 [OPTION]"
    echo
    echo -e "${YELLOW}Options:${NC}"
    echo "  -q, --quick      Quick login (OpenShift only)"
    echo "  -h, --help       Show this help message"
    echo "  --status, -s     Check current cluster status"
    echo "  --force, -f      Force OpenShift login (skip status check)"
    echo "  --debug          Enable debug output"
    echo
    echo -e "${GREEN}OpenShift mode (requires):${NC}"
    echo "  OCP_CLUSTER_URL  Cluster API URL (e.g., https://api.cluster.example.com:6443)"
    echo "  OCP_USERNAME     OpenShift username"
    echo "  OCP_CONTEXT      Context name (optional, auto-generated)"
    echo
    echo -e "${GREEN}Kubernetes mode (no login needed):${NC}"
    echo "  KUBECONFIG       Path to kubeconfig file (default: ~/.kube/config)"
    echo "  (No OCP_* variables needed)"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0                 # Interactive mode (detects cluster type)"
    echo "  $0 --status        # Check current cluster status"
    echo "  $0 --quick         # Quick OpenShift login"
    echo "  $0 --force         # Force OpenShift login"
    echo
    echo -e "${MAGENTA}Aliases in .bash_aliases:${NC}"
    echo "  alias ocl='ocp-login'                    # Interactive"
    echo "  alias oclq='ocp-login --quick'           # Quick OpenShift"
    echo "  alias ocls='ocp-login --status'          # Status check"
}

# Main function
main() {
    local command="interactive"
    local quick_mode=false
    local force_mode=false
    DEBUG="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -q|--quick)
                command="quick"
                quick_mode=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--status)
                command="status"
                shift
                ;;
            -f|--force)
                command="force"
                force_mode=true
                shift
                ;;
            --debug)
                DEBUG="true"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    case "${command}" in
        status)
            check_cluster_status "status"
            exit $?
            ;;
            
        quick|force)
            # Check if this is a Kubernetes cluster
            if ! prevent_k8s_quick_force; then
                exit 1
            fi
            
            if [ -z "${OCP_CLUSTER_URL}" ] || [ -z "${OCP_USERNAME}" ]; then
                log_error "Quick/Force login requires OpenShift configuration"
                log_error "Set OCP_CLUSTER_URL and OCP_USERNAME environment variables"
                echo
                log_info "Example:"
                log_info "  export OCP_CLUSTER_URL='https://api.openshift.example.com:6443'"
                log_info "  export OCP_USERNAME='your-username'"
                echo
                log_info "Or use predefined aliases like: ocl-dev, ocl-staging, ocl-prod"
                exit 1
            fi
            login_openshift "${quick_mode}"
            ;;
            
        interactive)
            # Default interactive mode
            echo -e "${CYAN}┌───────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}│                  Cluster Manager                  │${NC}"
            echo -e "${CYAN}└───────────────────────────────────────────────────┘${NC}"
            echo
            
            # First check current status
            if check_cluster_status "interactive"; then
                echo
                log_success "Already connected to cluster"
                
                # Determine actual cluster type
                local cli_tool="kubectl"
                if check_openshift_login; then
                    cli_tool="oc"
                fi
                
                if [ "${cli_tool}" = "oc" ]; then
                    read -p "Do you want to logout from OpenShift? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        ${cli_tool} logout 2>/dev/null
                        echo -e "${CHECKMARK} ${GREEN}Logged out${NC}"
                    fi
                else
                    read -p "Do you want to test cluster connection? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        echo
                        kubectl get nodes --request-timeout=5s --no-headers 2>/dev/null | head -5 | while read line; do
                            print_info "Node" "${line}" 2
                        done
                    fi
                fi
                
            else
                # Not connected or cannot connect
                echo
                
                # Check if we have OpenShift config
                if [ -n "${OCP_CLUSTER_URL}" ] && [ -n "${OCP_USERNAME}" ]; then
                    log_warn "Not connected to cluster"
                    echo
                    read -p "Do you want to login to ${OCP_CLUSTER_URL}? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        login_openshift "false"
                    else
                        log_info "Login cancelled"
                    fi
                else
                    # No OpenShift config, try Kubernetes
                    log_warn "Cannot connect to cluster"
                    handle_kubernetes
                fi
            fi
            ;;
    esac
}

# Run main function
main "$@"
