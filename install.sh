#!/bin/bash

# observability-stack installation script
# Installs Grafana observability stack (Mimir, Loki, Tempo, Grafana)

set -e  # Exit on any error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="observability"
CLUSTER_NAME="sre-lab"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}=== Observability Stack Installation ===${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm not found. Please install Helm first.${NC}"
    exit 1
fi

if ! command -v kind &> /dev/null; then
    echo -e "${RED}Error: kind not found. Please install kind first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites found${NC}"
echo ""

# Check if cluster exists
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${RED}Error: Cluster '${CLUSTER_NAME}' not found.${NC}"
    echo -e "${YELLOW}Please run the infra-cluster-kind/install.sh script first.${NC}"
    exit 1
fi

# Verify cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to cluster.${NC}"
    echo -e "${YELLOW}Run: kubectl config use-context kind-${CLUSTER_NAME}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Cluster '${CLUSTER_NAME}' is accessible${NC}"
echo ""

# Create namespace
echo -e "${GREEN}Creating namespace '${NAMESPACE}'...${NC}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespace ready${NC}"
echo ""

# Add Helm repositories
echo -e "${GREEN}Adding Helm repositories...${NC}"
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
echo -e "${GREEN}✓ Helm repositories updated${NC}"
echo ""

# Install Mimir
echo -e "${BLUE}=== Installing Grafana Mimir (Metrics) ===${NC}"
if helm list -n "${NAMESPACE}" | grep -q "^mimir"; then
    echo -e "${YELLOW}Mimir is already installed. Upgrading...${NC}"
fi
helm upgrade --install mimir grafana/mimir-distributed \
    -f "${SCRIPT_DIR}/charts/mimir/values-mimir.yaml" \
    -n "${NAMESPACE}" \
    --wait \
    --timeout 10m
echo -e "${GREEN}✓ Mimir installed successfully${NC}"
echo ""

# Install Loki
echo -e "${BLUE}=== Installing Grafana Loki (Logs) ===${NC}"
if helm list -n "${NAMESPACE}" | grep -q "^loki"; then
    echo -e "${YELLOW}Loki is already installed. Upgrading...${NC}"
fi
helm upgrade --install loki grafana/loki \
    -f "${SCRIPT_DIR}/charts/loki/values-loki.yaml" \
    -n "${NAMESPACE}" \
    --wait \
    --timeout 10m
echo -e "${GREEN}✓ Loki installed successfully${NC}"
echo ""

# Install Tempo
echo -e "${BLUE}=== Installing Grafana Tempo (Traces) ===${NC}"
if helm list -n "${NAMESPACE}" | grep -q "^tempo"; then
    echo -e "${YELLOW}Tempo is already installed. Upgrading...${NC}"
fi
helm upgrade --install tempo grafana/tempo \
    -f "${SCRIPT_DIR}/charts/tempo/values-tempo.yaml" \
    -n "${NAMESPACE}" \
    --wait \
    --timeout 10m
echo -e "${GREEN}✓ Tempo installed successfully${NC}"
echo ""

# Install Grafana
echo -e "${BLUE}=== Installing Grafana (Dashboards) ===${NC}"
if helm list -n "${NAMESPACE}" | grep -q "^grafana"; then
    echo -e "${YELLOW}Grafana is already installed. Upgrading...${NC}"
fi
helm upgrade --install grafana grafana/grafana \
    -f "${SCRIPT_DIR}/charts/grafana/values-grafana.yaml" \
    -n "${NAMESPACE}" \
    --wait \
    --timeout 5m
echo -e "${GREEN}✓ Grafana installed successfully${NC}"
echo ""

# Install OpenTelemetry Collector
echo -e "${BLUE}=== Installing OpenTelemetry Collector (Telemetry Pipeline) ===${NC}"
if helm list -n "${NAMESPACE}" | grep -q "^otel-collector"; then
    echo -e "${YELLOW}OTel Collector is already installed. Upgrading...${NC}"
fi
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
    -f "${SCRIPT_DIR}/charts/otel-collector/values-otel-collector.yaml" \
    -n "${NAMESPACE}" \
    --wait \
    --timeout 5m
echo -e "${GREEN}✓ OpenTelemetry Collector installed successfully${NC}"
echo ""

# Get Grafana admin password
echo -e "${YELLOW}Retrieving Grafana admin password...${NC}"
GRAFANA_PASSWORD=$(kubectl get secret --namespace "${NAMESPACE}" grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode)
if [ -n "$GRAFANA_PASSWORD" ]; then
    echo -e "${GREEN}✓ Grafana admin password retrieved${NC}"
else
    GRAFANA_PASSWORD="admin"
    echo -e "${YELLOW}Using default password: admin${NC}"
fi
echo ""

# Wait for LoadBalancer IPs
echo -e "${YELLOW}Waiting for LoadBalancer IPs to be assigned...${NC}"
echo "This may take up to 60 seconds..."
sleep 10

for i in {1..30}; do
    READY_COUNT=$(kubectl get svc -n "${NAMESPACE}" -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | select(.status.loadBalancer.ingress != null) | .metadata.name' | wc -l)
    TOTAL_COUNT=$(kubectl get svc -n "${NAMESPACE}" -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | .metadata.name' | wc -l)

    if [ "$READY_COUNT" -eq "$TOTAL_COUNT" ] && [ "$TOTAL_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ All LoadBalancer IPs assigned${NC}"
        break
    fi
    sleep 2
done
echo ""

# Display installation summary
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""

# List all Helm releases
echo -e "${BLUE}Installed Helm releases:${NC}"
helm list -n "${NAMESPACE}"
echo ""

# Display pod status
echo -e "${BLUE}Pod status:${NC}"
kubectl get pods -n "${NAMESPACE}" -o wide
echo ""

# Display service details
echo -e "${BLUE}Services and LoadBalancer IPs:${NC}"
kubectl get svc -n "${NAMESPACE}"
echo ""

# Extract and display access information
echo -e "${GREEN}=== Access Information ===${NC}"
echo ""

# Grafana
GRAFANA_IP=$(kubectl get svc grafana -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$GRAFANA_IP" ]; then
    echo -e "${BLUE}Grafana Dashboard:${NC}"
    echo "  URL: http://${GRAFANA_IP}"
    echo "  Username: admin"
    echo "  Password: ${GRAFANA_PASSWORD}"
    echo ""
fi

# Mimir
MIMIR_IP=$(kubectl get svc mimir-nginx -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$MIMIR_IP" ]; then
    echo -e "${BLUE}Mimir (Metrics):${NC}"
    echo "  Gateway: http://${MIMIR_IP}/prometheus"
    echo "  Query: http://${MIMIR_IP}/prometheus/api/v1/query"
    echo ""
fi

# Loki
LOKI_IP=$(kubectl get svc loki-gateway -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$LOKI_IP" ]; then
    echo -e "${BLUE}Loki (Logs):${NC}"
    echo "  Gateway: http://${LOKI_IP}"
    echo "  Push: http://${LOKI_IP}/loki/api/v1/push"
    echo "  Query: http://${LOKI_IP}/loki/api/v1/query"
    echo ""
fi

# Tempo
TEMPO_IP=$(kubectl get svc tempo -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$TEMPO_IP" ]; then
    echo -e "${BLUE}Tempo (Traces):${NC}"
    echo "  HTTP: http://${TEMPO_IP}:3200"
    echo "  OTLP gRPC: ${TEMPO_IP}:4317"
    echo "  OTLP HTTP: ${TEMPO_IP}:4318"
    echo ""
fi

# OpenTelemetry Collector
OTEL_IP=$(kubectl get svc otel-collector-opentelemetry-collector -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$OTEL_IP" ]; then
    echo -e "${BLUE}OpenTelemetry Collector (Telemetry Pipeline):${NC}"
    echo "  OTLP gRPC: ${OTEL_IP}:4317"
    echo "  OTLP HTTP: ${OTEL_IP}:4318"
    echo "  Metrics: http://${OTEL_IP}:8888/metrics"
    echo ""
fi

# Display storage
echo -e "${BLUE}Persistent Volumes:${NC}"
kubectl get pvc -n "${NAMESPACE}"
echo ""

# Next steps
echo -e "${GREEN}=== Next Steps ===${NC}"
echo ""
echo "1. Open Grafana in your browser: http://${GRAFANA_IP}"
echo "2. Explore the pre-configured datasources:"
echo "   - Mimir (Metrics)"
echo "   - Loki (Logs)"
echo "   - Tempo (Traces)"
echo ""
echo "3. Send telemetry to OpenTelemetry Collector:"
echo "   - OTLP gRPC endpoint: ${OTEL_IP}:4317"
echo "   - OTLP HTTP endpoint: ${OTEL_IP}:4318"
echo "   - Collector will forward logs→Loki, metrics→Mimir, traces→Tempo"
echo ""
echo "4. Useful commands:"
echo "   - View all pods: kubectl get pods -n ${NAMESPACE}"
echo "   - View logs: kubectl logs -l app.kubernetes.io/name=grafana -n ${NAMESPACE}"
echo "   - Port-forward Grafana: kubectl port-forward svc/grafana 3000:80 -n ${NAMESPACE}"
echo ""

# Optional: Open Grafana in browser
if [ -n "$GRAFANA_IP" ]; then
    read -p "Do you want to open Grafana in your default browser? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v xdg-open &> /dev/null; then
            xdg-open "http://${GRAFANA_IP}" &
        elif command -v open &> /dev/null; then
            open "http://${GRAFANA_IP}" &
        else
            echo -e "${YELLOW}Could not detect browser command. Please open manually: http://${GRAFANA_IP}${NC}"
        fi
    fi
fi

echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
