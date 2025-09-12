# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# VAULT KUBERNETES INTEGRATION - SERVICE AUTHENTICATION
# =============================================================================
# This file configures Vault integration with Kubernetes cluster for secure
# service-to-service authentication and secrets management

# -----------------------------------------------------------------------------
# KUBERNETES AUTHENTICATION BACKEND
# -----------------------------------------------------------------------------
# Enables Kubernetes authentication method for pod-based authentication
# Allows Kubernetes service accounts to authenticate with Vault

resource "vault_auth_backend" "k8s_low_layer" {
  type = "kubernetes"
  path = "kubernetes-low-layer"
}

resource "vault_kubernetes_auth_backend_config" "vault_operator_k8s_low_layer" {
  backend            = vault_auth_backend.k8s_low_layer.path
  kubernetes_host    = "https://kube.low-layer.internal"
  kubernetes_ca_cert = vault_pki_secret_backend_root_cert.pki_kubernetes_low_layer_cluster.issuing_ca
}

# -----------------------------------------------------------------------------
# TRANSIT ENCRYPTION ENGINE
# -----------------------------------------------------------------------------
# Provides encryption-as-a-service for Kubernetes secrets and cache encryption
# Enables secure storage of sensitive data without exposing encryption keys

resource "vault_mount" "transit_k8s_low_layer" {
  type        = "transit"
  path        = "transit-k8s-low-layer"
  description = "Transit encryption for Kubernetes cluster operations"
}

resource "vault_transit_secret_backend_key" "vso_client_cache_k8s_low_layer" {
  backend = vault_mount.transit_k8s_low_layer.path
  name    = "vso-client-cache"
}

resource "vault_transit_secret_backend_key" "k8s_service_account_k8s_low_layer" {
  backend     = vault_mount.transit_k8s_low_layer.path
  name        = "k8s-service-account"
  type        = "rsa-2048"
  exportable  = true
}

# -----------------------------------------------------------------------------
# KUBERNETES AUTHENTICATION ROLES
# -----------------------------------------------------------------------------
# Defines which Kubernetes service accounts can authenticate with Vault
# and what policies they receive upon successful authentication

resource "vault_kubernetes_auth_backend_role" "vault_auth_policy_operator_k8s_low_layer" {
  backend                          = vault_auth_backend.k8s_low_layer.path
  role_name                        = "vault-auth-role-operator-k8s-low-layer"
  bound_service_account_names      = ["vault-secrets-operator-controller-manager-k8s-low-layer"]
  bound_service_account_namespaces = ["vault"]
  token_ttl                        = 0
  token_policies                   = ["vault-auth-policy-operator-k8s-low-layer"]
  audience                         = "kube.low-layer.internal"
}

# -----------------------------------------------------------------------------
# VAULT SECURITY POLICIES
# -----------------------------------------------------------------------------
# Defines granular permissions for Kubernetes service accounts
# Follows principle of least privilege for secure operations

resource "vault_policy" "vault_auth_policy_operator_k8s_low_layer" {
  name = "vault-auth-policy-operator-k8s-low-layer"
  policy = <<-EOF
path "transit-k8s-low-layer/encrypt/vso-client-cache" {
   capabilities = ["create", "update"]
}
path "transit-k8s-low-layer/decrypt/vso-client-cache" {
   capabilities = ["create", "update"]
}
EOF
}

resource "vault_policy" "k8s_service_account_policy_operator_k8s_low_layer" {
  name = "k8s-service-account-policy-operator-k8s-low-layer"
  policy = <<-EOF
path "transit-k8s-low-layer/export/signing-key/k8s-service-account" {
   capabilities = ["read"]
}
path "transit-k8s-low-layer/export/public-key/k8s-service-account" {
   capabilities = ["read"]
}
EOF
}

# =============================================================================
# OPERATIONAL NOTES
# =============================================================================
# 
# Authentication Flow:
# - Kubernetes pods authenticate using service account JWT tokens
# - Vault validates tokens against Kubernetes API server
# - Successful authentication grants access based on assigned policies
# 
# Key Management:
# - VSO client cache key: AES-256 encryption for Vault Secrets Operator cache
# - Service account key: RSA-2048 for Kubernetes service account token signing
# - All keys are managed by Vault's transit engine for secure operations