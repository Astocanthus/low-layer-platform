# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# VAULT STATIC SECRET MANAGEMENT RESOURCES
# =============================================================================
# This file creates the necessary resources to retrieve static secrets from Vault
# through the Vault Secrets Operator in a Kubernetes cluster

# -----------------------------------------------------------------------------
# KUBERNETES SERVICE ACCOUNT
# -----------------------------------------------------------------------------
# Service account that will be used by the Vault Secrets Operator
# to authenticate with Vault and access secrets

resource "kubernetes_service_account" "vault_operator" {
  metadata {
    name      = "vault-operator-secrets"
    namespace = var.namespace
  }
}

# -----------------------------------------------------------------------------
# VAULT POLICY
# -----------------------------------------------------------------------------
# Defines the permissions that the service account will have in Vault
# Allows read access to the specified secret paths

resource "vault_policy" "vault_operator" {
  name = "kubernetes-access-vault-secrets-${var.namespace}"

  policy = join("\n", [
    for secret in var.secrets : <<-EOP
    # Allow read access to Vault secret path ${secret.path}
    path "${secret.mount}/data/${secret.path}" {
      capabilities = ["read"]
    }

    path "${secret.mount}/metadata/${secret.path}" {
      capabilities = ["list"]
    }
    EOP
  ])
}

# -----------------------------------------------------------------------------
# VAULT AUTHENTICATION BACKEND ROLE
# -----------------------------------------------------------------------------
# Configures the Kubernetes authentication method in Vault to allow
# the service account to authenticate and obtain tokens

resource "vault_kubernetes_auth_backend_role" "vault_operator" {
  backend                          = var.auth_mount
  role_name                        = "vault-operator-${var.namespace}"
  bound_service_account_names      = [kubernetes_service_account.vault_operator.metadata[0].name]
  bound_service_account_namespaces = [var.namespace]
  token_ttl                        = 0
  token_period                     = 120
  token_policies                   = [vault_policy.vault_operator.name]
  audience                         = var.audience
}

# -----------------------------------------------------------------------------
# KUBERNETES RBAC
# -----------------------------------------------------------------------------
# Grants the service account the necessary permissions to perform
# token review operations required by Vault's Kubernetes auth method

resource "kubernetes_cluster_role_binding" "vault_operator_auth_delegator" {
  metadata {
    name = "vault-operator-auth-delegator-${var.namespace}"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_operator.metadata[0].name
    namespace = var.namespace
  }
}

# -----------------------------------------------------------------------------
# VAULT SECRETS OPERATOR - AUTHENTICATION
# -----------------------------------------------------------------------------
# Configures the VaultAuth custom resource that tells the Vault Secrets Operator
# how to authenticate with Vault using the Kubernetes auth method

resource "kubernetes_manifest" "vault_auth" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultAuth"
    metadata = {
      name      = "vault-auth-secrets-${var.namespace}"
      namespace = var.namespace
    }
    spec = {
      method     = "kubernetes"
      mount      = var.auth_mount
      kubernetes = {
        role           = vault_kubernetes_auth_backend_role.vault_operator.role_name
        serviceAccount = kubernetes_service_account.vault_operator.metadata[0].name
        audiences      = [
          var.audience
        ]
      }
    }
  }
}

# -----------------------------------------------------------------------------
# VAULT SECRETS OPERATOR - STATIC SECRET RETRIEVAL
# -----------------------------------------------------------------------------
# Creates VaultStaticSecret resources for each secret defined in the variables
# Each resource will retrieve an existing secret from Vault and create a Kubernetes secret
# Transformation doc : https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso/sources/vault

resource "kubernetes_manifest" "vault_static_secret" {
  for_each = { for s in var.secrets : s.name => s }

  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultStaticSecret"
    metadata = {
      name      = each.value.name
      namespace = var.namespace
    }
    spec = {
      vaultAuthRef = kubernetes_manifest.vault_auth.manifest.metadata.name
      mount        = each.value.mount
      path         = each.value.path
      type         = each.value.type
      version      = each.value.version
      refreshAfter = each.value.refreshAfter
      destination  = {
        create         = true
        name           = each.value.name
        labels         = each.value.labels
        type           = "Opaque"
        transformation = each.value.transformation
      }
    }
  }
}