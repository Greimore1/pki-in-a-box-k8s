terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
    helm       = { source = "hashicorp/helm", version = "~> 2.13" }
  }
}
variable "kubeconfig" { type = string, default = "~/.kube/config" }
provider "kubernetes" { config_path = var.kubeconfig }
provider "helm" { kubernetes { config_path = var.kubeconfig } }

resource "kubernetes_manifest" "namespaces" {
  manifest = yamldecode(file("${path.module}/../../k8s/base/namespaces.yaml"))
}

resource "helm_release" "loki" {
  name = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart = "loki-stack"
  namespace = "telemetry"
  create_namespace = true
  version = "2.10.2"
}

resource "helm_release" "tempo" {
  name = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart = "tempo"
  namespace = "telemetry"
  version = "1.4.1"
  depends_on = [helm_release.loki]
}

resource "helm_release" "kps" {
  name = "kps"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart = "kube-prometheus-stack"
  namespace = "telemetry"
  version = "58.3.0"
  depends_on = [helm_release.tempo]
}

resource "kubernetes_manifest" "netpol" {
  manifest = yamldecode(file("${path.module}/../../k8s/base/networkpolicies.yaml"))
  depends_on = [kubernetes_manifest.namespaces]
}

resource "kubernetes_manifest" "step_secret" {
  manifest = yamldecode(file("${path.module}/../../k8s/step-ca/secret.yaml"))
  depends_on = [kubernetes_manifest.namespaces]
}

resource "kubernetes_manifest" "step_stateful" {
  manifest = yamldecode(file("${path.module}/../../k8s/step-ca/statefulset.yaml"))
  depends_on = [kubernetes_manifest.step_secret]
}

resource "kubernetes_manifest" "step_svc" {
  manifest = yamldecode(file("${path.module}/../../k8s/step-ca/service.yaml"))
  depends_on = [kubernetes_manifest.step_stateful]
}

resource "kubernetes_manifest" "otel_cm" {
  manifest = yamldecode(file("${path.module}/../../telemetry/otel-configmap.yaml"))
  depends_on = [helm_release.kps]
}

resource "kubernetes_manifest" "otel_deploy" {
  manifest = yamldecode(file("${path.module}/../../telemetry/otel-collector.yaml"))
  depends_on = [kubernetes_manifest.otel_cm]
}

resource "helm_release" "pki_api" {
  name = "pki-api"
  chart = "${path.module}/../../k8s/pki-api"
  namespace = "pki"
  create_namespace = true
  values = ["${path.module}/../../k8s/pki-api/values.yaml"]
  depends_on = [kubernetes_manifest.step_svc, kubernetes_manifest.otel_deploy]
}
