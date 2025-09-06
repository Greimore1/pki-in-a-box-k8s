# PKI-in-a-Box: Kubernetes Edition (Lean)

[![CI](https://github.com/Greimore1/pki-in-a-box-k8s/actions/workflows/ci.yml/badge.svg)](https://github.com/Greimore1/pki-in-a-box-k8s/actions/workflows/ci.yml)
[![IaC Validate](https://github.com/Greimore1/pki-in-a-box-k8s/actions/workflows/iac-validate.yml/badge.svg)](https://github.com/Greimore1/pki-in-a-box-k8s/actions/workflows/iac-validate.yml)

A cost-free local blueprint that models a UK-first PKI programme on a single-node Kubernetes cluster. This repo demonstrates Terraform and Helm based infrastructure as code, GitHub Actions CI, secure-by-design controls, full telemetry across metrics, logs, and traces, containerisation, and hybrid host onboarding with Ansible. The design maps one-to-one to AWS so you can explain production choices without deploying or incurring costs.

## Quick start
Prerequisites: Docker, kind, kubectl, Helm, Ansible (optional).

For a fuller walkthrough, see [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md).

```bash
./scripts/cluster-up.sh
cd terraform/local && terraform init && terraform plan
# Optional: terraform apply
../../scripts/smoke.sh
```

## AWS mapping
| Local | AWS | Notes |
| --- | --- | --- |
| step-ca | AWS Private CA | Local CA avoids PCA flat fee. |
| PKI API on K8s | API Gateway + Lambda or ECS | API contract matches. |
| Prometheus, Loki, Tempo, Grafana | CloudWatch, AMP, X-Ray, Managed Grafana | Three pillars are represented. |
| K8s Secrets | Secrets Manager + KMS | Same intent. |
| kind networking | VPC, subnets, security groups | NetworkPolicies mirror SGs. |
| Hybrid host | On-prem or EC2 with SSM | Same flow. |

## Cost
Local only and free.

## Security highlights
No committed secrets, TLS defaults, minimal RBAC, default deny NetworkPolicies, CI scans for IaC and containers.

## How it works in 60 seconds
- step-ca acts as the issuing CA inside the cluster.
- The PKI API receives a CSR, applies basic policy checks, then asks step-ca to sign.
- A hybrid Linux host (via Ansible) requests a cert and serves an mTLS-protected path with Nginx.
- Metrics, logs and traces flow through the OpenTelemetry Collector into Prometheus, Loki, Tempo, then appear in Grafana.

## Sample outputs
```
$ curl -s http://localhost:30001/healthz
{"ok":true}

$ kubectl get pods -A
NAMESPACE     NAME                                   READY   STATUS    RESTARTS   AGE
kube-system   coredns-...                             1/1     Running   0          2m
pki           step-ca-0                               1/1     Running   0          1m
pki           pki-api-...                             1/1     Running   0          30s
telemetry     otel-collector-...                      1/1     Running   0          45s
telemetry     kps-grafana-...                         1/1     Running   0          50s
...
```
