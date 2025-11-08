# observability-stack

Complete Grafana observability platform for Kubernetes: metrics (Mimir), logs (Loki), traces (Tempo), and unified visualization (Grafana).

---

## Purpose

Provides a production-like observability stack for learning **the three pillars of observability**:
- **Metrics:** Grafana Mimir (Prometheus-compatible, distributed mode with MinIO backend)
- **Logs:** Grafana Loki (SingleBinary mode, optimized for Kind)
- **Traces:** Grafana Tempo (monolithic mode)
- **Visualization:** Grafana (pre-configured with all three datasources)
- **Telemetry Pipeline:** OpenTelemetry Collector (OTLP receivers → backends)

**Why this stack?** Industry-standard observability tools used in production by major organizations. Learn once, apply everywhere.

---

## What's Included

```
observability-stack/
├── install.sh                          # Automated Helm installation
├── check-dependencies.sh               # Verify prerequisites
├── charts/
│   ├── mimir/
│   │   └── values-mimir.yaml          # Distributed mode with MinIO
│   ├── loki/
│   │   └── values-loki.yaml           # SingleBinary, caches disabled
│   ├── tempo/
│   │   └── values-tempo.yaml          # Monolithic mode
│   ├── grafana/
│   │   └── values-grafana.yaml        # Pre-configured datasources
│   └── otel-collector/
│       └── values-otel-collector.yaml # OTLP receivers and exporters
└── docs/
    └── bootstrap.md                    # Advanced configuration
```

All components installed via **Helm** with versioned values files.

---

## Prerequisites

### Required Infrastructure

⚠️ **This component requires `infra-cluster-kind` to be installed first.**

```bash
cd ../infra-cluster-kind
./install.sh
```

**Why:** Needs a Kubernetes cluster with MetalLB LoadBalancer support.

### Required Tools

- **kubectl** 1.31.0+ (Kubernetes CLI)
- **helm** 3.19.0+ (Kubernetes package manager)
- **jq** (JSON processor, used by scripts)
- **kind** 0.23.0+ (to verify cluster exists)

### Verify Prerequisites

```bash
./check-dependencies.sh
```

### System Requirements

**Storage:** ~11Gi persistent volumes will be allocated:
- Mimir MinIO: 5Gi
- Loki: 3Gi (filesystem, caches disabled)
- Tempo: 2Gi (filesystem)
- Grafana: 1Gi

**Memory:** ~4-6GB for all observability pods (tuned for Kind with 3 workers)

---

## Installation

### Automated Installation (Recommended)

```bash
./install.sh
```

**What it does:**
1. Verifies cluster `sre-lab` exists
2. Creates namespace `observability`
3. Adds Helm repositories (grafana, open-telemetry)
4. Installs all components via Helm (Mimir → Loki → Tempo → Grafana → OTel Collector)
5. Waits for LoadBalancer IPs to be assigned
6. Displays access information and credentials

**Script behavior:**
- **Idempotent**: Uses `helm upgrade --install` (safe to re-run)
- **Interactive**: Offers to open Grafana in browser
- **Self-documenting**: Shows all endpoints and next steps

**Installation time:** ~8-12 minutes (Helm pulls images and waits for readiness)

### Manual Installation

If you need step-by-step control, see the commands inside `install.sh`. Key steps:

```bash
# Create namespace
kubectl create namespace observability

# Add Helm repos
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Install components (in order)
helm install mimir grafana/mimir-distributed -f charts/mimir/values-mimir.yaml -n observability
helm install loki grafana/loki -f charts/loki/values-loki.yaml -n observability
helm install tempo grafana/tempo -f charts/tempo/values-tempo.yaml -n observability
helm install grafana grafana/grafana -f charts/grafana/values-grafana.yaml -n observability
helm install otel-collector open-telemetry/opentelemetry-collector -f charts/otel-collector/values-otel-collector.yaml -n observability
```

---

## Verification

### Check Installation

```bash
# List Helm releases
helm list -n observability

# Check pod status (all should be Running)
kubectl get pods -n observability -o wide

# Check services (all LoadBalancers should have EXTERNAL-IP)
kubectl get svc -n observability

# Check persistent volumes
kubectl get pvc -n observability
```

### Access Grafana

```bash
# Get Grafana URL
GRAFANA_IP=$(kubectl get svc grafana -n observability -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "http://${GRAFANA_IP}"

# Get admin password
kubectl get secret grafana -n observability -o jsonpath="{.data.admin-password}" | base64 -d
# Default: admin/admin
```

Open in browser and verify all three datasources are configured:
1. Navigate to ☰ → Connections → Data sources
2. Test each datasource (Mimir, Loki, Tempo)
3. All should show green "Data source is working" message

---

## Architecture

### Data Flow

```
Application with OpenTelemetry SDK
        ↓ (OTLP: traces, metrics, logs)
OpenTelemetry Collector (gRPC 4317, HTTP 4318)
        ↓         ↓         ↓
     Loki     Mimir     Tempo
     (Logs)   (Metrics) (Traces)
        ↓         ↓         ↓
           Grafana (Query & Visualize)
```

### Component Modes

| Component | Mode | Why This Mode? |
|-----------|------|----------------|
| **Mimir** | Distributed | Learn production architecture (ingester, querier, compactor, store-gateway) |
| **Loki** | SingleBinary | Simpler for Kind, fewer resources, still learns Loki concepts |
| **Tempo** | Monolithic | Sufficient for learning, fewer moving parts |
| **Grafana** | Standalone | Standard deployment |
| **OTel Collector** | Standalone | Central telemetry gateway |

### Network

All components exposed as **LoadBalancer** services (MetalLB assigns IPs):

```bash
kubectl get svc -n observability -o wide
```

Expected services:
- `grafana` → Port 80 (HTTP UI)
- `mimir-nginx` → Port 80 (Mimir gateway)
- `loki-gateway` → Port 80 (Loki gateway)
- `tempo` → Ports 3200 (HTTP), 4317 (OTLP gRPC), 4318 (OTLP HTTP)
- `otel-collector-opentelemetry-collector` → Ports 4317 (OTLP gRPC), 4318 (OTLP HTTP)

---

## Access Information

After installation, get all endpoints:

### Grafana Dashboard

```bash
GRAFANA_IP=$(kubectl get svc grafana -n observability -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "http://${GRAFANA_IP}"
```

**Credentials:** admin/admin (change in values-grafana.yaml for production)

### Mimir (Metrics)

```bash
MIMIR_IP=$(kubectl get svc mimir-nginx -n observability -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Gateway: http://${MIMIR_IP}/prometheus"
echo "Query API: http://${MIMIR_IP}/prometheus/api/v1/query"
```

**Use cases:**
- Prometheus remote write endpoint
- PromQL queries via Grafana
- Direct API access for testing

### Loki (Logs)

```bash
LOKI_IP=$(kubectl get svc loki-gateway -n observability -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Gateway: http://${LOKI_IP}"
echo "Push API: http://${LOKI_IP}/loki/api/v1/push"
echo "Query API: http://${LOKI_IP}/loki/api/v1/query"
```

**Use cases:**
- Log ingestion endpoint
- LogQL queries via Grafana
- Direct API access for testing

### Tempo (Traces)

```bash
TEMPO_IP=$(kubectl get svc tempo -n observability -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "HTTP: http://${TEMPO_IP}:3200"
echo "OTLP gRPC: ${TEMPO_IP}:4317"
echo "OTLP HTTP: ${TEMPO_IP}:4318"
```

**Use cases:**
- OTLP trace ingestion
- TraceQL queries via Grafana
- Direct API access for testing

### OpenTelemetry Collector

```bash
OTEL_IP=$(kubectl get svc otel-collector-opentelemetry-collector -n observability -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "OTLP gRPC: ${OTEL_IP}:4317"
echo "OTLP HTTP: ${OTEL_IP}:4318"
echo "Metrics: http://${OTEL_IP}:8888/metrics"
```

**Recommended approach:** Send all telemetry to OTel Collector, which routes to appropriate backends.

---

## Configuration

All configurations are in versioned `values-*.yaml` files. Key customizations:

### Mimir (`charts/mimir/values-mimir.yaml`)

```yaml
# Distributed mode with MinIO backend
mimir:
  structuredConfig:
    blocks_storage:
      backend: s3  # Uses MinIO (S3-compatible)
```

**Why distributed?** Learn production architecture with separate components (ingester, querier, compactor, etc.)

### Loki (`charts/loki/values-loki.yaml`)

```yaml
deploymentMode: SingleBinary  # All components in one pod
loki:
  commonConfig:
    replication_factor: 1
  schemaConfig:
    configs:
      - from: 2024-01-01
        store: tsdb
        object_store: filesystem
        schema: v13
```

**Optimizations:**
- Caches disabled to save memory
- Filesystem storage (no S3)
- TSDB index for better performance

### Tempo (`charts/tempo/values-tempo.yaml`)

```yaml
tempo:
  storage:
    trace:
      backend: local  # Filesystem storage
```

**Why monolithic?** Simpler for learning, sufficient for Kind environment.

### Grafana (`charts/grafana/values-grafana.yaml`)

```yaml
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Mimir
        type: prometheus
        url: http://mimir-nginx.observability.svc.cluster.local/prometheus
      - name: Loki
        type: loki
        url: http://loki-gateway.observability.svc.cluster.local
      - name: Tempo
        type: tempo
        url: http://tempo.observability.svc.cluster.local:3200
```

**Pre-configured:** All datasources automatically configured at installation.

---

## Helm Management

### List Releases

```bash
helm list -n observability
```

### Upgrade a Component

After modifying a values file:

```bash
helm upgrade <release-name> <chart> \
  -f charts/<component>/values-<component>.yaml \
  -n observability
```

Example (Grafana):
```bash
helm upgrade grafana grafana/grafana \
  -f charts/grafana/values-grafana.yaml \
  -n observability
```

### Uninstall a Component

```bash
helm uninstall <release-name> -n observability
```

### Known Issue: Mimir Upgrades

⚠️ **Mimir webhook conflicts:** If `helm upgrade mimir` fails with webhook errors from `mimir-rollout-operator`:

```bash
# Use uninstall + fresh install instead
helm uninstall mimir -n observability
helm install mimir grafana/mimir-distributed \
  -f charts/mimir/values-mimir.yaml \
  -n observability
```

---

## Troubleshooting

### Pending LoadBalancer IPs

**Symptom:** Services stuck with `<pending>` EXTERNAL-IP

**Diagnosis:**
```bash
# Check MetalLB
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l app=metallb

# Verify IP pool
kubectl get ipaddresspool -n metallb-system
```

**Solution:** Ensure `infra-cluster-kind` MetalLB is working correctly. See `../infra-cluster-kind/README.md`.

### Pod Crashes or OOMKilled

**Symptom:** Pods in `CrashLoopBackOff` or constantly restarting

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n observability

# View pod logs
kubectl logs <pod-name> -n observability --tail=100

# Check resource usage
kubectl top pods -n observability
```

**Common causes:**
1. Insufficient memory (increase Docker resources)
2. Storage issues (check PVCs)
3. Configuration errors (review values files)

### Datasource Connectivity Issues

**Symptom:** Grafana can't connect to Mimir/Loki/Tempo

**Diagnosis:**
```bash
# Check service endpoints
kubectl get endpoints -n observability

# Test from Grafana pod
kubectl exec -n observability -it deployment/grafana -- wget -O- http://mimir-nginx/prometheus/api/v1/status/buildinfo
kubectl exec -n observability -it deployment/grafana -- wget -O- http://loki-gateway/ready
kubectl exec -n observability -it deployment/grafana -- wget -O- http://tempo:3200/ready
```

**Solution in Grafana UI:**
1. Navigate to ☰ → Connections → Data sources
2. Click on failing datasource
3. Click "Save & test" button
4. Check error message for details

### Helm Installation Hangs

**Symptom:** `helm install` waits indefinitely

**Cause:** Helm waits for pods to be ready (--wait flag in install.sh)

**Diagnosis:**
```bash
# Check pod status in another terminal
kubectl get pods -n observability -w

# Check events
kubectl get events -n observability --sort-by='.lastTimestamp'
```

**Solution:**
- Let it run (can take 10+ minutes for image pulls)
- Or cancel (Ctrl+C) and troubleshoot pod issues

### DNS Failures (Critical)

**Symptom:** Pods can't resolve cluster DNS, nginx-based gateways failing

**Likely cause:** Inotify exhaustion (if cluster running 45+ hours)

**Diagnosis:**
```bash
# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check inotify usage
for foo in /proc/*/fd/*; do readlink -f $foo; done | grep inotify | wc -l
```

**Solution:** See `../SRE-laboratory/docs/runbooks/cluster-dns-failure-inotify-exhaustion.md`

---

## Storage Details

Persistent volumes created by Helm:

```bash
kubectl get pvc -n observability
```

Expected PVCs:
- `storage-mimir-minio-*` (5Gi) - MinIO object storage for Mimir blocks
- `storage-loki-*` (3Gi) - Loki chunks and indexes
- `storage-tempo-*` (2Gi) - Tempo traces
- `grafana` (1Gi) - Grafana dashboards and settings

**Storage class:** Uses Kind's default `standard` (local-path provisioner)

**Backup:** Data persists across pod restarts but not cluster deletion.

---

## Next Steps

After successful installation:

1. **Send test data:**
   - Deploy a sample application with OpenTelemetry SDK
   - Point OTLP exporter to `${OTEL_IP}:4317`
   - View metrics/logs/traces in Grafana

2. **Explore Grafana:**
   - Create dashboards querying Mimir (PromQL)
   - Search logs in Loki (LogQL)
   - Trace requests in Tempo (TraceQL)
   - See correlations (metrics → logs → traces)

3. **Learn observability concepts:**
   - Cardinality and metrics best practices
   - Log aggregation and structured logging
   - Distributed tracing and span context
   - Service level objectives (SLOs)

4. **Experiment:**
   - Modify values files and upgrade releases
   - Break things and fix them (safe environment!)
   - Review runbooks in `../SRE-laboratory/docs/runbooks/`

---

## Learning Resources

### Official Documentation

- **Grafana Mimir:** https://grafana.com/docs/mimir/latest/
- **Grafana Loki:** https://grafana.com/docs/loki/latest/
- **Grafana Tempo:** https://grafana.com/docs/tempo/latest/
- **Grafana:** https://grafana.com/docs/grafana/latest/
- **OpenTelemetry:** https://opentelemetry.io/docs/

### Key Concepts

- **Prometheus data model:** Metrics, labels, cardinality
- **LogQL:** Loki's query language (similar to PromQL for logs)
- **TraceQL:** Tempo's query language for traces
- **OTLP:** OpenTelemetry Protocol (standard telemetry format)
- **Exemplars:** Linking metrics to traces

---

## Advanced Topics

### Scaling for Production

Current setup is optimized for Kind (3 workers, ~11Gi storage). For production:

1. **Mimir:** Increase replicas, enable HA, use real S3
2. **Loki:** Switch to distributed mode (microservices)
3. **Tempo:** Use distributed mode, enable S3 backend
4. **Grafana:** Enable HA, external database, LDAP/OAuth
5. **OTel Collector:** Run as DaemonSet, add processors

See `docs/bootstrap.md` for advanced configuration.

### Multi-tenancy

All components support multi-tenancy via `X-Scope-OrgID` header. Enable in values files for learning about tenant isolation.

### High Availability

For HA observability:
- Multiple Grafana replicas (external database required)
- Mimir replication factor > 1
- Loki replication factor > 1
- Multiple OTel Collector replicas

---

**Part of:** [SRE Lab](../README.md)
**Previous Component:** [infra-cluster-kind](../infra-cluster-kind/README.md)
**Next Component:** [SRE-laboratory](../SRE-laboratory/README.md)
