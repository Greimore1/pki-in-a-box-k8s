#!/usr/bin/env bash
set -euo pipefail
openssl genrsa -out key.pem 2048
openssl req -new -key key.pem -out req.csr -subj "/CN=local.internal.example"
