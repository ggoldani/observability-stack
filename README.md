 Observability Stack

A complete Grafana observability stack for local Kubernetes (kind + MetalLB):
- **Metrics**: Grafana Mimir (Prometheus-compatible)
- **Logs**: Grafana Loki (planned)
- **Traces**: Grafana Tempo (planned)
- **Dashboards**: Grafana

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
   kubectl apply -f metallb/  # Your IP pool and L2Advertisement YAMLs
   
3. Install Mimir:
      helm repo add grafana https://grafana.github.io/helm-charts
   helm install mimir grafana/mimir-distributed -f charts/mimir/values-mimir.yaml -n observability --create-namespace
   
4. Install Grafana:
      helm install grafana grafana/grafana -f charts/grafana/values-grafana.yaml -n observability
   
5. (Optional) Install Loki and Tempo:
   - Update values files in charts/
   - helm install loki grafana/loki -f charts/loki/values-loki.yaml -n observability
   - helm install tempo grafana/tempo -f charts/tempo/values-tempo.yaml -n observability

Access
- Mimir: kubectl get svc -n observability (gateway LoadBalancer IP) → /prometheus
- Grafana: kubectl get svc -n observability (LoadBalancer IP) → Login admin/admin
- Port-forward fallback: kubectl port-forward svc/<service> 3000:80 -n observability

Configuration
- Values files in charts/ are tuned for kind with 3 workers.
- Change passwords, enable auth, and scale replicas for production.
- See docs/bootstrap.md for advanced setup.

Troubleshooting
- Pending LoadBalancer IPs: Check MetalLB pods and IP pool.
- Pod crashes: kubectl logs <pod> -n observability
- For issues, check Helm releases: helm list -n observability

Contribute or report issues at https://github.com/ggoldani/observability-stack
