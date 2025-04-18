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
