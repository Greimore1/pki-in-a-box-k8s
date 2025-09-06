#!/usr/bin/env bash
set -euo pipefail
kubectl get pods -A
echo "Try: curl -s http://localhost:30001/healthz"
