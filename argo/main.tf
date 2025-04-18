terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.1"
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = "https://kubernetes.default.svc"
    cluster_ca_certificate = file("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
    token                  = file("/var/run/secrets/kubernetes.io/serviceaccount/token")
  }
}

resource "helm_release" "jenkins" {  
  name             = "jenkins"
  chart            = "jenkins"
  repository       = "https://charts.jenkins.io"
  namespace        = "jenkins"
  create_namespace = true
  version          = "5.8.33"
  timeout          = 600

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "500m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "512Mi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "1000m"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  set {
    name  = "controller.javaOpts"
    value = "-Xmx512m -Xms256m"
  }

  set {
    name  = "controller.containerEnv[0].name"
    value = "JAVA_OPTS"
  }

  set {
    name  = "controller.containerEnv[0].value"
    value = "-Djenkins.install.runSetupWizard=false"
  }

  set {
    name  = "controller.startupProbe.initialDelaySeconds"
    value = "120"
  }

  set {
    name  = "controller.startupProbe.periodSeconds"
    value = "10"
  }

  set {
    name  = "controller.startupProbe.timeoutSeconds"
    value = "5"
  }

  set {
    name  = "controller.startupProbe.failureThreshold"
    value = "30"
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  chart            = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.51.4"  # Specify a stable version

  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  set {
    name  = "controller.args.appResyncPeriod"
    value = "30"
  }
}

resource "helm_release" "vault" {
  name             = "vault"
  chart            = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  namespace        = "vault"
  create_namespace = true
  version          = "0.27.0"

  set {
    name  = "server.dev.enabled"
    value = "true"
  }

  set {
    name  = "injector.enabled"
    value = "false"
  }
}

# --- External Secrets Operator (ESO) ---
resource "helm_release" "eso" {
  name             = "external-secrets"
  chart            = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  namespace        = "external-secrets"
  create_namespace = true
  version          = "0.9.19"

  set {
    name  = "installCRDs"
    value = "true"
  }
}


resource "null_resource" "wait_for_clustersecretstore_crd" {
  depends_on = [helm_release.eso]

  provisioner "local-exec" {
    command = <<EOT
      echo "⏳ Waiting for ClusterSecretStore CRD to be ready..."
      for i in {1..20}; do
        if kubectl get crd clustersecretstores.external-secrets.io > /dev/null 2>&1; then
          echo "✅ ClusterSecretStore CRD is ready!"
          exit 0
        fi
        echo "Retrying... ($i)"
        sleep 3
      done
      echo "❌ CRD not found after waiting"
      exit 1
    EOT
  }
}


# --- Vault Token Secret для ESO ---
resource "kubernetes_secret" "vault_token" {
  metadata {
    name      = "vault-token"
    namespace = "external-secrets"
  }

  data = {
    token = base64encode("root") # В dev-режиме Vault токен всегда 'root'
  }

  type = "Opaque"
}

# --- ClusterSecretStore для Vault ---
resource "kubernetes_manifest" "vault_cluster_secret_store" {
  depends_on = [null_resource.wait_for_clustersecretstore_crd]

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "vault-backend"
    }
    spec = {
      provider = {
        vault = {
          server   = "http://vault.vault.svc.cluster.local:8200"
          path     = "secret"
          version  = "v2"
          auth = {
            tokenSecretRef = {
              name      = "vault-token"
              namespace = "external-secrets"
              key       = "token"
            }
          }
        }
      }
    }
  }
}
