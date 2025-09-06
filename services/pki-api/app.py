import os, subprocess, tempfile
from typing import List, Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

STEP_CA_URL = os.getenv("STEP_CA_URL", "http://step-ca.pki.svc:9000")
STEP_PROV = os.getenv("STEP_PROVISIONER", "admin")
STEP_PW = os.getenv("STEP_PROVISIONER_PASSWORD", "changeit")
POLICY_SUFFIX = os.getenv("POLICY_DOMAIN_SUFFIX", ".internal.example")

app = FastAPI()

class SignReq(BaseModel):
    csr_pem: str
    validity: Optional[str] = "24h"
    common_name: Optional[str] = None
    sans: Optional[List[str]] = []

class RevokeReq(BaseModel):
    serial: str
    reason: Optional[str] = "keyCompromise"

def check_policy(cn: Optional[str], sans: List[str]):
    if cn and not cn.endswith(POLICY_SUFFIX):
        raise HTTPException(status_code=400, detail=f"CN must end with {POLICY_SUFFIX}")
    for s in sans or []:
        if not s.endswith(POLICY_SUFFIX):
            raise HTTPException(status_code=400, detail=f"SAN {s} must end with {POLICY_SUFFIX}")

@app.get("/healthz")
def healthz():
    return {"ok": True}

@app.get("/crl")
def crl():
    return {"crl": "demo-crl-not-implemented"}

@app.post("/csr/sign")
def sign(req: SignReq):
    check_policy(req.common_name, req.sans or [])
    with tempfile.TemporaryDirectory() as d:
        csr_path = os.path.join(d, "req.csr")
        with open(csr_path, "w") as f:
            f.write(req.csr_pem)
        crt_path = os.path.join(d, "cert.pem")
        pw_path = os.path.join(d, "pw.txt")
        with open(pw_path, "w") as f:
            f.write(STEP_PW)
        cmd = ["step","ca","sign","--not-after", req.validity or "24h",
               "--ca-url", STEP_CA_URL, "--provisioner", STEP_PROV,
               "--provisioner-password-file", pw_path, csr_path, crt_path]
        try:
            subprocess.run(cmd, check=True, capture_output=True, text=True)
            with open(crt_path, "r") as f:
                cert_pem = f.read()
            return {"certificate": cert_pem, "certificate_chain": ""}
        except subprocess.CalledProcessError as e:
            raise HTTPException(status_code=500, detail=e.stderr or str(e))

@app.post("/cert/revoke")
def revoke(req: RevokeReq):
    return {"revoked": req.serial, "reason": req.reason}
