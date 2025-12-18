# ==============================================================================
# OPENSHIFT CLUSTERS - COMPLETE LOGIN ALIASES
# ==============================================================================

# Example: Development OpenShift cluster
ocl-dev() {
    export OCP_CLUSTER_URL="https://api.dev-cluster.example.com:6443"
    export OCP_USERNAME="developer"
    export KUBECONFIG=~/.kube/config_ocp_dev
    echo "🔵 Development OpenShift: $OCP_CLUSTER_URL"
    echo "👤 User: $OCP_USERNAME"
    ocp-login
}

# Example: Staging OpenShift cluster
ocl-staging() {
    export OCP_CLUSTER_URL="https://api.staging-cluster.example.com:6443"
    export OCP_USERNAME="tester"
    export KUBECONFIG=~/.kube/config_ocp_staging
    echo "🟡 Staging OpenShift: $OCP_CLUSTER_URL"
    echo "👤 User: $OCP_USERNAME"
    ocp-login
}

# Example: Production OpenShift cluster
ocl-prod() {
    export OCP_CLUSTER_URL="https://api.prod-cluster.example.com:6443"
    export OCP_USERNAME="operator"
    export KUBECONFIG=~/.kube/config_ocp_prod
    echo "🔴 Production OpenShift: $OCP_CLUSTER_URL"
    echo "👤 User: $OCP_USERNAME"
    ocp-login
}

# Quick login versions (non-interactive)
ocl-dev-quick() {
    export OCP_CLUSTER_URL="https://api.dev-cluster.example.com:6443"
    export OCP_USERNAME="developer"
    export KUBECONFIG=~/.kube/config_ocp_dev
    echo "🔵 Development OpenShift - Quick login"
    ocp-login --quick
}

ocl-staging-quick() {
    export OCP_CLUSTER_URL="https://api.staging-cluster.example.com:6443"
    export OCP_USERNAME="tester"
    export KUBECONFIG=~/.kube/config_ocp_staging
    echo "🟡 Staging OpenShift - Quick login"
    ocp-login --quick
}

# Status check only
ocl-dev-status() {
    export KUBECONFIG=~/.kube/config_ocp_dev
    ocp-login --status
}

ocl-staging-status() {
    export KUBECONFIG=~/.kube/config_ocp_staging
    ocp-login --status
}

# ==============================================================================
# GENERIC OPENSHIFT FUNCTIONS
# ==============================================================================

# Quick login to current OpenShift cluster (uses already set variables)
alias ocl='ocp-login'
alias oclq='ocp-login --quick'
alias ocls='ocp-login --status'

# Set cluster without login (for manual control)
set-ocp() {
    if [ $# -ne 3 ]; then
        echo "Usage: set-ocp <url> <username> <kubeconfig>"
        echo "Example: set-ocp https://api.example.com:6443 user ~/.kube/config_example"
        return 1
    fi
    
    export OCP_CLUSTER_URL="$1"
    export OCP_USERNAME="$2"
    export KUBECONFIG="$3"
    
    echo "✅ OpenShift cluster set:"
    echo "   URL: $OCP_CLUSTER_URL"
    echo "   User: $OCP_USERNAME"
    echo "   Config: $KUBECONFIG"
}

# ==============================================================================
# PURE KUBERNETES CLUSTERS (no OpenShift login needed)
# ==============================================================================

# Example: Internal Kubernetes cluster
ocl-internal() {
    export KUBECONFIG="${HOME}/.kube/internal_config"
    echo "✅ Internal Kubernetes cluster"
    kubectl cluster-info 2>/dev/null || echo "⚠️  Not connected or cluster unavailable"
}

# Example: External Kubernetes cluster
ocl-external() {
    export KUBECONFIG="${HOME}/.kube/external_config"
    echo "✅ External Kubernetes cluster"
    kubectl cluster-info 2>/dev/null || echo "⚠️  Not connected or cluster unavailable"
}

# ==============================================================================
# CLOUD PROVIDER CLUSTERS (example templates)
# ==============================================================================

# Azure AKS cluster example
ocl-aks-dev() {
    echo "⚠️  Placeholder: Add your AKS login script here"
    echo "Example: az aks get-credentials --resource-group rg-dev --name aks-dev"
    export KUBECONFIG=~/.kube/config_aks_dev
}

# AWS EKS cluster example
ocl-eks-prod() {
    echo "⚠️  Placeholder: Add your EKS login script here"
    echo "Example: aws eks update-kubeconfig --region us-east-1 --name eks-prod"
    export KUBECONFIG=~/.kube/config_eks_prod
}

# Google GKE cluster example
ocl-gke-test() {
    echo "⚠️  Placeholder: Add your GKE login script here"
    echo "Example: gcloud container clusters get-credentials gke-test --region europe-west1"
    export KUBECONFIG=~/.kube/config_gke_test
}

# ==============================================================================
# LEGACY/EXISTING SCRIPT INTEGRATION (example)
# ==============================================================================

# Example integration with existing login scripts
ocl-legacy-cluster1() {
    if [ -f ~/scr/login-cluster1.sh ]; then
        ~/scr/login-cluster1.sh
        export KUBECONFIG=~/.kube/config_cluster1
    else
        echo "❌ Login script not found: ~/scr/login-cluster1.sh"
    fi
}

ocl-legacy-cluster2() {
    if [ -f ~/scr/login-cluster2.sh ]; then
        ~/scr/login-cluster2.sh
        export KUBECONFIG=~/.kube/config_cluster2
    else
        echo "❌ Login script not found: ~/scr/login-cluster2.sh"
    fi
}

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

# Clear current kubeconfig selection
alias kube-clear='unset KUBECONFIG'

# List available kubeconfigs
kube-list() {
    echo "📁 Available kubeconfigs:"
    local configs=($(ls ~/.kube/config_* ~/.kube/config-* 2>/dev/null))
    if [ ${#configs[@]} -eq 0 ]; then
        echo "   No kubeconfigs found"
    else
        for config in "${configs[@]}"; do
            echo "   ${config##*/}"
        done
    fi
}

# Show current kubeconfig
alias kube-show='echo "📋 Current KUBECONFIG: ${KUBECONFIG:-~/.kube/config}"'
alias kube-current='echo "📋 Current KUBECONFIG: ${KUBECONFIG:-~/.kube/config}"'

# Switch between kubeconfigs
kube-switch() {
    local configs=($(ls ~/.kube/config_* ~/.kube/config-* 2>/dev/null))
    
    if [ ${#configs[@]} -eq 0 ]; then
        echo "❌ No kubeconfigs found in ~/.kube/"
        return 1
    fi
    
    echo "📋 Available kubeconfigs:"
    for i in "${!configs[@]}"; do
        echo "  $((i+1)). ${configs[$i]##*/}"
    done
    
    read -p "Select config number: " choice
    
    if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#configs[@]} ]; then
        export KUBECONFIG="${configs[$((choice-1))]}"
        echo "✅ Switched to: $KUBECONFIG"
    else
        echo "❌ Invalid selection"
    fi
}

# Test cluster connection
kube-test() {
    echo "🧪 Testing cluster connection..."
    if kubectl cluster-info &> /dev/null; then
        echo "✅ Cluster is accessible"
        kubectl cluster-info | head -2
    else
        echo "❌ Cannot connect to cluster"
    fi
}

# Get current context
alias kube-context='kubectl config current-context'
alias kube-ctx='kubectl config current-context'

# List all contexts
kube-contexts() {
    echo "🔀 Available contexts:"
    kubectl config get-contexts
}

# Switch context
kube-context-switch() {
    kubectl config get-contexts
    read -p "Enter context name to switch to: " ctx
    kubectl config use-context "$ctx" 2>/dev/null && echo "✅ Switched to context: $ctx" || echo "❌ Failed to switch context"
}

# ==============================================================================
# QUICK KUBERNETES COMMANDS
# ==============================================================================

# Common kubectl shortcuts
alias pods='kubectl get pods -A'
alias nodes='kubectl get nodes'
alias services='kubectl get services -A'
alias deployments='kubectl get deployments -A'
alias ingresses='kubectl get ingresses -A'
alias namespaces='kubectl get namespaces'

# OpenShift specific shortcuts
alias oc-projects='oc get projects'
alias oc-who='oc whoami'
alias oc-status='oc status'

# ==============================================================================
# SETUP INSTRUCTIONS (for documentation)
# ==============================================================================

# To use these aliases:
# 1. Copy this file to ~/.bash_aliases or source it in your ~/.bashrc
# 2. Install the ocp-login script: sudo install ocp-login.sh /usr/local/bin/ocp-login
# 3. Customize the cluster URLs, usernames, and kubeconfig paths above
# 4. Source your bash configuration: source ~/.bashrc
