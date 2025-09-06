#!/usr/bin/env bash
set -euo pipefail
kind create cluster --name pki --config k8s/kind-cluster.yaml
kubectl apply -f k8s/base/namespaces.yaml
