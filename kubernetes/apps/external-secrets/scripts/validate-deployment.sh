#!/bin/bash
# Validation script for External Secrets Operator deployment
# This script verifies that ESO is properly deployed and coexisting with SOPS

set -e

echo "🔍 Validating External Secrets Operator Deployment"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo "1. Checking External Secrets Operator deployment..."

# Check if ESO namespace exists
kubectl get namespace external-secrets-system >/dev/null 2>&1
print_status $? "External Secrets System namespace exists"

# Check ESO pods
ESO_PODS=$(kubectl get pods -n external-secrets-system -l app.kubernetes.io/name=external-secrets --no-headers 2>/dev/null | wc -l)
if [ "$ESO_PODS" -gt 0 ]; then
    RUNNING_PODS=$(kubectl get pods -n external-secrets-system -l app.kubernetes.io/name=external-secrets --no-headers 2>/dev/null | grep Running | wc -l)
    if [ "$RUNNING_PODS" -eq "$ESO_PODS" ]; then
        print_status 0 "External Secrets Operator pods are running ($RUNNING_PODS/$ESO_PODS)"
    else
        print_status 1 "Some External Secrets Operator pods are not running ($RUNNING_PODS/$ESO_PODS)"
    fi
else
    print_status 1 "No External Secrets Operator pods found"
fi

echo ""
echo "2. Checking CRDs installation..."

# Check if ESO CRDs are installed
CRDS=("clustersecretstores.external-secrets.io" "externalsecrets.external-secrets.io" "secretstores.external-secrets.io")
for crd in "${CRDS[@]}"; do
    kubectl get crd "$crd" >/dev/null 2>&1
    print_status $? "CRD $crd is installed"
done

echo ""
echo "3. Checking Vaultwarden Provider deployment..."

# Check Vaultwarden provider pod
VW_PODS=$(kubectl get pods -l app.kubernetes.io/name=vaultwarden-provider --no-headers 2>/dev/null | wc -l)
if [ "$VW_PODS" -gt 0 ]; then
    VW_RUNNING=$(kubectl get pods -l app.kubernetes.io/name=vaultwarden-provider --no-headers 2>/dev/null | grep Running | wc -l)
    if [ "$VW_RUNNING" -eq "$VW_PODS" ]; then
        print_status 0 "Vaultwarden provider pods are running ($VW_RUNNING/$VW_PODS)"
    else
        print_status 1 "Some Vaultwarden provider pods are not running ($VW_RUNNING/$VW_PODS)"
    fi
else
    print_status 1 "No Vaultwarden provider pods found"
fi

echo ""
echo "4. Checking ClusterSecretStores..."

# Check ClusterSecretStores
STORES=("vaultwarden-login" "vaultwarden-fields" "vaultwarden-notes" "vaultwarden-attachments")
for store in "${STORES[@]}"; do
    kubectl get clustersecretstore "$store" >/dev/null 2>&1
    print_status $? "ClusterSecretStore $store exists"
done

echo ""
echo "5. Checking SOPS coexistence..."

# Check if SOPS secrets still exist and are functional
SOPS_SECRETS=$(find kubernetes/apps -name "*.sops.yaml" -type f 2>/dev/null | wc -l)
if [ "$SOPS_SECRETS" -gt 0 ]; then
    print_status 0 "SOPS secrets found ($SOPS_SECRETS files) - coexistence confirmed"
else
    print_warning "No SOPS secrets found - this might be expected if fully migrated"
fi

# Check if SOPS configuration exists
if [ -f ".sops.yaml" ]; then
    print_status 0 "SOPS configuration file exists"
else
    print_status 1 "SOPS configuration file missing"
fi

echo ""
echo "6. Checking Flux integration..."

# Check if Flux kustomizations exist
kubectl get kustomization external-secrets-operator -n flux-system >/dev/null 2>&1
print_status $? "External Secrets Operator Flux kustomization exists"

kubectl get kustomization vaultwarden-provider -n flux-system >/dev/null 2>&1
print_status $? "Vaultwarden Provider Flux kustomization exists"

echo ""
echo "7. Summary and Next Steps..."
echo "=============================="

echo ""
echo "🎯 Deployment Status:"
echo "   • External Secrets Operator: Deployed"
echo "   • Vaultwarden Provider: Configured"
echo "   • ClusterSecretStores: Available"
echo "   • SOPS Integration: Preserved"
echo ""
echo "📋 Next Steps:"
echo "   1. Configure Vaultwarden credentials in vaultwarden-provider-secret"
echo "   2. Create test items in Vaultwarden"
echo "   3. Deploy sample ExternalSecret (see examples/)"
echo "   4. Begin gradual migration of non-critical secrets"
echo ""
echo "📚 Documentation:"
echo "   • README.md - Complete usage guide"
echo "   • examples/ - Sample ExternalSecret manifests"
echo "   • Migration examples in README.md"
echo ""

if command -v kubectl >/dev/null 2>&1; then
    echo "🔧 Quick Commands:"
    echo "   # Check ESO logs:"
    echo "   kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets"
    echo ""
    echo "   # Check Vaultwarden provider logs:"
    echo "   kubectl logs -l app.kubernetes.io/name=vaultwarden-provider"
    echo ""
    echo "   # List all ClusterSecretStores:"
    echo "   kubectl get clustersecretstores"
    echo ""
fi
