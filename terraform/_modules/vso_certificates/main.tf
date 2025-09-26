# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# VAULT PKI CERTIFICATE MANAGEMENT RESOURCES
# =============================================================================
# This file creates the necessary resources for PKI certificate management
# through Vault in a Kubernetes cluster using the Vault Secrets Operator

# -----------------------------------------------------------------------------
# KUBERNETES SERVICE ACCOUNT
# -----------------------------------------------------------------------------
# Service account that will be used by the Vault Secrets Operator
# to authenticate with Vault and manage certificates

resource "kubernetes_service_account" "vault_operator" {
  metadata {
    name      = "vault-operator-${var.pki_name}-${var.pki_issuer}-${var.pki_role}"
    namespace = var.namespace
  }
}

# -----------------------------------------------------------------------------
# VAULT POLICY
# -----------------------------------------------------------------------------
# Defines the permissions that the service account will have in Vault
# Allows access to the PKI engine for certificate generation

resource "vault_policy" "vault_operator" {
  name = "kubernetes-access-vault-${var.namespace}-${var.pki_name}-${var.pki_issuer}-${var.pki_role}"
  
  policy = <<-EOF
# Allow access to the PKI issuer for certificate generation
path "${var.pki_name}/issue/${var.pki_role}" {
  capabilities = ["create", "update"]
}
EOF
}

# -----------------------------------------------------------------------------
# VAULT AUTHENTICATION BACKEND ROLE
# -----------------------------------------------------------------------------
# Configures the Kubernetes authentication method in Vault to allow
# the service account to authenticate and obtain tokens

resource "vault_kubernetes_auth_backend_role" "vault_operator" {
  backend                          = var.auth_mount
  role_name                        = "vault-operator-${var.namespace}-${var.pki_name}-${var.pki_issuer}-${var.pki_role}"
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
    name = "vault-operator-auth-delegator-${var.namespace}-${var.pki_name}-${var.pki_issuer}-${var.pki_role}"
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
      name      = "vault-auth-${var.pki_name}-${var.pki_issuer}-${var.pki_role}"
      namespace = var.namespace
    }
    spec = {
      method     = "kubernetes"
      mount      = var.auth_mount
      kubernetes = {
        role           = vault_kubernetes_auth_backend_role.vault_operator.role_name
        serviceAccount = kubernetes_service_account.vault_operator.metadata[0].name
        audiences = [
          var.audience
        ]
      }
    }
  }
}

# -----------------------------------------------------------------------------
# VAULT SECRETS OPERATOR - PKI CERTIFICATES
# -----------------------------------------------------------------------------
# Creates VaultPKISecret resources for each certificate defined in the variables
# Each resource will generate and manage a certificate from Vault PKI

resource "kubernetes_manifest" "vault_pki" {
  for_each = { for cert in var.certificates : cert.secretName => cert }

  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultPKISecret"
    metadata = {
      name      = each.value.secretName
      namespace = var.namespace
    }
    spec = {
      vaultAuthRef = kubernetes_manifest.vault_auth.manifest.metadata.name
      mount        = var.pki_name
      role         = var.pki_role
      commonName   = each.value.cn
      altNames     = each.value.altNames
      format       = each.value.format
      expiryOffset = each.value.expiryOffset
      ttl          = each.value.ttl
      destination = {
        create = true
        name   = each.value.secretName
      }
    }
  }
}

# Futur proof

# resource "vault_kubernetes_auth_backend_role" "vault_operator" {
#   backend                          = var.auth_mount
#   role_name                        = "vault-operator-${var.namespace}-${var.pki_name}-${var.pki_role}"
#   bound_service_account_names      = [kubernetes_service_account.vault_operator.metadata[0].name]
#   bound_service_account_namespaces = [var.namespace]
#   token_ttl                        = 0
#   token_period                     = 120
#   token_policies                   = [vault_policy.vault_operator.name]
#   audience                         = var.audience
# }

# resource "vault_pki_secret_backend_cert" "certs" {
#   for_each = { for cert in var.certificates : cert.secretName => cert }

#   backend       = var.pki_name
#   name          = each.value.cn
#   common_name   = each.value.cn
#   alt_names     = each.value.altNames
#   ttl           = each.value.ttl
#   format        = each.value.format
#   expiry        = each.value.expiryOffset != "" ? each.value.expiryOffset : null
# }