# Bootstrap

## Namespace
kubectl create namespace observability

## Help repos
- helm repo add grafana https://grafana.github.io/helm-charts
- helm repo update

## Notes
- components will be installed wiith 'helm upgrade --install' and versioned 'values.yaml'
- services will use 'type:LoadBalancer' to receive EXTERNAL-IP from metalLB
