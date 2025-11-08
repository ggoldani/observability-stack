#!/bin/bash

# check-dependencies.sh for observability-stack
# Verifies all required dependencies are installed before stack deployment

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Dependency Check for Observability Stack ===${NC}"
echo ""

# Track overall status
ALL_GOOD=true

# Check kubectl
echo -n "Checking kubectl... "
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | awk '{print $3}')
    echo -e "${GREEN}✓${NC} (${KUBECTL_VERSION})"

    # Check cluster connectivity
    if kubectl cluster-info &> /dev/null; then
        CLUSTER_NAME=$(kubectl config current-context)
        echo -e "  ${GREEN}✓${NC} Connected to cluster: ${CLUSTER_NAME}"

        # Verify it's the sre-lab cluster
        if [[ "$CLUSTER_NAME" == *"sre-lab"* ]]; then
            echo -e "  ${GREEN}✓${NC} Correct cluster context"
        else
            echo -e "  ${YELLOW}⚠${NC}  Not connected to 'sre-lab' cluster"
            echo -e "      Switch with: kubectl config use-context kind-sre-lab"
        fi
    else
        echo -e "  ${RED}✗${NC} Cannot connect to any cluster"
        echo -e "      Run infra-cluster-kind/install.sh first"
        ALL_GOOD=false
    fi
else
    echo -e "${RED}✗ NOT FOUND${NC}"
    echo -e "  Install: https://kubernetes.io/docs/tasks/tools/"
    ALL_GOOD=false
fi

# Check Helm
echo -n "Checking Helm... "
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short 2>/dev/null | awk '{print $1}')
    echo -e "${GREEN}✓${NC} (${HELM_VERSION})"
else
    echo -e "${RED}✗ NOT FOUND${NC}"
    echo -e "  Install: https://helm.sh/docs/intro/install/"
    ALL_GOOD=false
fi

# Check kind (for cluster verification)
echo -n "Checking kind... "
if command -v kind &> /dev/null; then
    KIND_VERSION=$(kind version | awk '{print $2}')
    echo -e "${GREEN}✓${NC} (${KIND_VERSION})"

    # Check if sre-lab cluster exists
    if kind get clusters 2>/dev/null | grep -q "^sre-lab$"; then
        echo -e "  ${GREEN}✓${NC} sre-lab cluster exists"
    else
        echo -e "  ${RED}✗${NC} sre-lab cluster not found"
        echo -e "      Create it with: cd ../infra-cluster-kind && ./install.sh"
        ALL_GOOD=false
    fi
else
    echo -e "${RED}✗ NOT FOUND${NC}"
    echo -e "  Install: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    ALL_GOOD=false
fi

# Check jq (required by install script for JSON parsing)
echo -n "Checking jq... "
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version | awk -F'-' '{print $2}')
    echo -e "${GREEN}✓${NC} (${JQ_VERSION})"
else
    echo -e "${RED}✗ NOT FOUND${NC}"
    echo -e "  Install: sudo apt-get install jq (Debian/Ubuntu)"
    ALL_GOOD=false
fi

# Check curl (needed by Helm)
echo -n "Checking curl... "
if command -v curl &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ NOT FOUND${NC}"
    echo -e "  Install: sudo apt-get install curl (Debian/Ubuntu)"
    ALL_GOOD=false
fi

echo ""
echo -e "${GREEN}=== Cluster Readiness Checks ===${NC}"
echo ""

if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
    # Check if MetalLB is installed
    echo -n "Checking MetalLB... "
    if kubectl get namespace metallb-system &> /dev/null; then
        METALLB_PODS=$(kubectl get pods -n metallb-system --no-headers 2>/dev/null | wc -l)
        METALLB_READY=$(kubectl get pods -n metallb-system --no-headers 2>/dev/null | grep -c "Running")

        if [ "$METALLB_PODS" -eq "$METALLB_READY" ] && [ "$METALLB_PODS" -gt 0 ]; then
            echo -e "${GREEN}✓${NC} (${METALLB_READY}/${METALLB_PODS} pods running)"
        else
            echo -e "${YELLOW}⚠${NC}  (${METALLB_READY}/${METALLB_PODS} pods running)"
            echo -e "    Some MetalLB pods may not be ready"
        fi
    else
        echo -e "${RED}✗ NOT INSTALLED${NC}"
        echo -e "    MetalLB is required for LoadBalancer services"
        echo -e "    Run: cd ../infra-cluster-kind && ./install.sh"
        ALL_GOOD=false
    fi

    # Check node count
    echo -n "Checking cluster nodes... "
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready")

    if [ "$NODE_COUNT" -ge 4 ]; then
        echo -e "${GREEN}✓${NC} (${READY_NODES}/${NODE_COUNT} ready)"
    else
        echo -e "${YELLOW}⚠${NC}  Only ${NODE_COUNT} nodes (expected: 4)"
        echo -e "    The stack may still work but with reduced capacity"
    fi
fi

echo ""
echo -e "${GREEN}=== Summary ===${NC}"
echo ""

if [ "$ALL_GOOD" = true ]; then
    echo -e "${GREEN}✓ All dependencies satisfied!${NC}"
    echo -e "Ready to run: ./install.sh"
    exit 0
else
    echo -e "${RED}✗ Some dependencies are missing or misconfigured.${NC}"
    echo -e "Please install/configure missing items and run this check again."
    exit 1
fi
