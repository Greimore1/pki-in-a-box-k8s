FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl ca-certificates && rm -rf /var/lib/apt/lists/*
RUN curl -L https://dl.smallstep.com/cli/docs-cli-install/latest/step-cli_amd64.deb -o /tmp/step-cli.deb     && apt-get update && apt-get install -y /tmp/step-cli.deb && rm /tmp/step-cli.deb
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py openapi.yaml policy/ ./
ENV STEP_CA_URL=http://step-ca.pki.svc:9000
ENV STEP_PROVISIONER=admin
ENV STEP_PROVISIONER_PASSWORD=changeit
ENV POLICY_DOMAIN_SUFFIX=.internal.example
EXPOSE 8080
CMD ["uvicorn","app:app","--host","0.0.0.0","--port","8080"]
