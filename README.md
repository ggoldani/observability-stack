 Observability Stack

  A complete Grafana observability stack for local Kubernetes (kind + MetalLB):
  - **Metrics**: Grafana Mimir (Prometheus-compatible, distributed mode)
  - **Logs**: Grafana Loki (SingleBinary mode)
  - **Traces**: Grafana Tempo (monolithic mode)
  - **Dashboards**: Grafana (with all 3 datasources pre-configured)

All components installed via Helm with versioned values files.
 Prerequisites
- [kind](https://kind.sigs.k8s.io/) cluster with 3+ workers
- [MetalLB](https://metallb.universe.tf/) for LoadBalancer services
- [Helm](https://helm.sh/) v3+
- kubectl

 Installation

1. **Create kind cluster**:
    kind create cluster --config kind-cluster-3w.yaml

2. Install MetalLB:
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
    
    kubectl apply -f metallb/  # IP pool and L2Advertisement YAMLs
   
3. Install Mimir:
    helm repo add grafana https://grafana.github.io/helm-charts
   
    helm install mimir grafana/mimir-distributed -f charts/mimir/values-mimir.yaml -n observability --create-namespace

4. Install Loki (logs):
    helm install loki grafana/loki -f charts/loki/values-loki.yaml -n observability

Note: Uses SingleBinary mode with 3Gi filesystem storage. Cache components
disabled to save memory.

5. Install Tempo (traces):
    helm install tempo grafana/tempo -f charts/tempo/values-tempo.yaml -n observability

Note: Uses monolithic mode with 2Gi filesystem storage. Service exposed as
LoadBalancer.
   
6. Install Grafana (dashboards):
    helm install grafana grafana/grafana -f charts/grafana/values-grafana.yam -n observability

Note: Pre-configured with Mimir, Loki, and Tempo datasources. Full
correlation enabled between metrics, logs, and traces.

Access
- Mimir: kubectl get svc mimir-gateway -n observability →  http://<EXTERNAL-IP>/prometheus
- Loki: kubectl get svc loki-gateway -n observability → http://<EXTERNAL-IP>
- Tempo: kubectl get svc tempo -n observability → http://<EXTERNAL-IP>:3200
- Grafana: kubectl get svc grafana -n observability → http://<EXTERNAL-IP>
- Login: admin/admin (change in production)
- All datasources pre-configured and ready to use

Configuration
- Values files in charts/ are tuned for kind with 3 workers.
- Change passwords, enable auth, and scale replicas for production.
- See docs/bootstrap.md for advanced setup.
Storage allocation (optimized for 25GB VM):
  - Mimir MinIO: 5Gi
  - Loki: 3Gi (filesystem, caches disabled)
  - Tempo: 2Gi (filesystem)
  - Grafana: 1Gi
  - Total: ~11Gi persistent storage

Troubleshooting
- Pending LoadBalancer IPs: Check MetalLB pods and IP pool.
- Pod crashes: kubectl logs <pod> -n observability
- For issues, check Helm releases: helm list -n observability

**Webhook conflicts during upgrades:**
If you see webhook errors from `mimir-rollout-operator`, use `helm uninstall` and fresh `helm install` instead of `helm upgrade`.

**Memory issues:**
If pods show "Insufficient memory", the cache components in Loki can be disabled (already done in values-loki.yaml).

**Datasource connectivity:**
Verify datasources in Grafana: ☰ → Connections → Data sources. Click "Test" on each datasource.

Contribute or report issues at https://github.com/ggoldani/observability-stack
