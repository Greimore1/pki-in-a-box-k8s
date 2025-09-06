# Getting started

This is a minimal, end to end run on a laptop. It exists for reviewers who want to reproduce the flow. You do not need to run any of this to assess the project.

## Prerequisites

Install the following on your machine:

- Docker
- kind
- kubectl
- Helm
- Terraform
- OpenSSL
- jq
- Ansible (only if you want to run the "hybrid host" step)

Verify they are on PATH:

```bash
docker --version
kind --version
kubectl version --client
helm version
terraform version
openssl version
jq --version
ansible --version
```

## Bring up the cluster

```bash
# Create a single-node local cluster and namespaces
./scripts/cluster-up.sh

# Confirm the cluster is reachable
kubectl get nodes
kubectl get ns
```

## Install the stack with Terraform

```bash
cd terraform/local
terraform init
terraform apply -auto-approve
```

This installs:
- step-ca in the `pki` namespace
- the PKI API exposed on NodePort `30001`
- telemetry plane in `telemetry` (Prometheus, Loki, Tempo, Grafana) and an OpenTelemetry Collector

Check pods:

```bash
kubectl get pods -A
```

## Sanity check the API

```bash
curl -s http://localhost:30001/healthz
# Expected: {"ok":true}
```

## Issue a certificate from your terminal

```bash
# Generate a key and CSR
cd ../../services/pki-api
openssl genrsa -out key.pem 2048
openssl req -new -key key.pem -out req.csr -subj "/CN=local.internal.example"

# Call the PKI API to sign the CSR
CSR_JSON=$(awk 'BEGIN{RS=""; gsub(/\n/,"\\n")}1' req.csr)
curl -s http://localhost:30001/csr/sign   -H "Content-Type: application/json"   -d "{"csr_pem":"$CSR_JSON","validity":"24h","common_name":"local.internal.example","sans":["local.internal.example"]}"   | jq -r .certificate > cert.pem

# Verify a certificate was returned
test -s cert.pem && echo "Certificate written to cert.pem"
```

## Optional: simulate a hybrid host with Ansible

The role generates a key and CSR, requests a certificate, installs Nginx with TLS, and enables an mTLS-protected path at `/internal`.

```bash
ansible-playbook -i "localhost," -c local ansible/roles/hybrid_host/tasks/main.yml   -e pki_api_url=http://localhost:30001   -e pki_cn=host1.internal.example
```

## Observe

Grafana is installed by kube-prometheus-stack. Port-forward it locally:

```bash
# In a new terminal
kubectl -n telemetry port-forward svc/kps-grafana 3000:80
```

Open http://localhost:3000 and import the dashboard JSON from:
```
telemetry/grafana-dashboard-pki-ops.json
```

You can also check raw signals:

```bash
# API health
curl -s http://localhost:30001/healthz

# Logs (example: show pki-api logs)
kubectl -n pki logs deploy/pki-api --tail=100

# Prometheus targets
kubectl -n telemetry port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090
# Then open http://localhost:9090 in your browser
```

## Teardown

```bash
# Remove Kubernetes resources created by Terraform
cd terraform/local
terraform destroy -auto-approve || true

# Delete the local cluster
kind delete cluster --name pki
```

## Troubleshooting

- If `curl http://localhost:30001/healthz` fails, ensure the `pki-api` Service is NodePort 30001:
  ```bash
  kubectl -n pki get svc pki-api -o yaml | grep -A3 nodePort
  kubectl -n pki get deploy pki-api
  ```
- If Grafana is not reachable, recheck the port-forward and that the `kps-grafana` Service exists:
  ```bash
  kubectl -n telemetry get svc kps-grafana
  ```
- If Terraform cannot talk to the cluster, confirm your kubeconfig points to the kind cluster:
  ```bash
  kubectl config current-context
  kubectl config get-contexts
  ```
