# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# SYSTEM VAULT SECRETS OPERATOR DEPLOYMENT
# =============================================================================
# Deploy HashiCorp Vault Secrets Operator for automated secrets management
# Integrates Vault with Kubernetes for secure secrets synchronization

# -----------------------------------------------------------------------------
# VAULT SECRETS OPERATOR CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for Vault operator deployment

locals {
  vault_config = {
    chart_version = "0.10.0"
    repository    = "https://helm.releases.hashicorp.com"
    namespace     = "system-vault"
    timeout       = 150
  }
}

# -----------------------------------------------------------------------------
# SYSTEM VAULT NAMESPACE
# -----------------------------------------------------------------------------
# Dedicated namespace for Vault Secrets Operator with Istio ambient mode

resource "kubernetes_namespace" "system_vault" {
  metadata {
    name = local.vault_config.namespace
    labels = {
      "app.kubernetes.io/managed-by"               = "terraform"
      "app.kubernetes.io/component"                = "vault-secrets-operator"
      "istio.io/dataplane-mode"                    = "ambient"
      "pod-security.kubernetes.io/enforce"         = "baseline"
      "pod-security.kubernetes.io/enforce-version" = "latest"
    }
  }
}

# -----------------------------------------------------------------------------
# PKI CERTIFICATE AUTHORITY CONFIGURATION
# -----------------------------------------------------------------------------
# Retrieve internal CA certificate from Vault PKI backend

data "vault_pki_secret_backend_issuers" "pki_ca" {
  backend = "pki"
}

locals {
  # Parse PKI issuers information from Vault
  issuers = jsondecode(data.vault_pki_secret_backend_issuers.pki_ca.key_info_json)

  # Create issuer name to ID mapping for easier lookup
  issuers_by_name = {
    for id, info in local.issuers :
    info["issuer_name"] => id
  }
}

data "vault_pki_secret_backend_issuer" "internal_ca" {
  backend    = data.vault_pki_secret_backend_issuers.pki_ca.backend
  issuer_ref = local.issuers_by_name["low-layer.internal"]
}

# -----------------------------------------------------------------------------
# INTERNAL CA SECRET
# -----------------------------------------------------------------------------
# Store internal CA certificate as Kubernetes secret for TLS verification

resource "kubernetes_secret_v1" "internal_ca" {
  metadata {
    name      = "internal-ca"
    namespace = kubernetes_namespace.system_vault.metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "vault-ca-certificate"
    }
  }

  data = {
    "ca.crt" = data.vault_pki_secret_backend_issuer.internal_ca.certificate
  }
  
  type = "Opaque"
}

# -----------------------------------------------------------------------------
# VAULT SECRETS OPERATOR DEPLOYMENT
# -----------------------------------------------------------------------------
# Deploy the main Vault Secrets Operator using Helm

resource "helm_release" "vault_secrets_operator" {
  name       = "vault-secrets-operator"
  repository = local.vault_config.repository
  chart      = "vault-secrets-operator"
  version    = local.vault_config.chart_version
  namespace  = kubernetes_namespace.system_vault.metadata[0].name
  timeout    = local.vault_config.timeout

  # Load operator configuration from external values file
  values = [
    file("helm_values/system_vault_secrets_operator.yaml")
  ]

  # Ensure proper cleanup order
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true

  depends_on = [
    helm_release.cni_cilium,
    kubernetes_secret_v1.internal_ca
  ]
}

# -----------------------------------------------------------------------------
# DEFAULT VAULT CONNECTION
# -----------------------------------------------------------------------------
# Configure default connection to Vault server with CA certificate

resource "kubectl_manifest" "default_vault_connection" {
  yaml_body = yamlencode({
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultConnection"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace.system_vault.metadata[0].name
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "vault-connection"
      }
    }
    spec = {
      address         = "https://vault.internal"
      caCertSecretRef = kubernetes_secret_v1.internal_ca.metadata[0].name
    }
  })

  depends_on = [
    helm_release.vault_secrets_operator,
    kubernetes_secret_v1.internal_ca
  ]
}