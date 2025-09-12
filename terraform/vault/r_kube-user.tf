# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# VAULT KUBERNETES USER MANAGEMENT - OIDC IDENTITY INTEGRATION
# =============================================================================
# This file manages Kubernetes users, groups, and policies for OIDC-based
# authentication and authorization through Vault identity management

# -----------------------------------------------------------------------------
# KUBERNETES USERPASS AUTHENTICATION BACKEND
# -----------------------------------------------------------------------------
# Provides username/password authentication for Kubernetes OIDC integration
# Enables traditional credential-based access alongside service account tokens

resource "vault_auth_backend" "kubernetes_userpass" {
  type = "userpass"
  path = "kubernetes-userpass"
}

# -----------------------------------------------------------------------------
# KUBERNETES USER CREDENTIALS
# -----------------------------------------------------------------------------
# Defines user accounts for Kubernetes cluster access via OIDC
# Users authenticate through Vault to receive OIDC tokens for kube-apiserver

resource "vault_generic_endpoint" "kube_admin" {
  depends_on = [vault_auth_backend.kubernetes_userpass]
  path       = "auth/kubernetes-userpass/users/kube-admin-oidc"

  data_json = <<-EOF
  {
    "password": "password1"
  }
EOF
}

resource "vault_generic_endpoint" "kube_reader" {
  depends_on = [vault_auth_backend.kubernetes_userpass]
  path       = "auth/kubernetes-userpass/users/kube-reader-oidc"

  data_json = <<-EOF
  {
    "password": "password2"
  }
EOF
}

data "vault_identity_entity" "terraform_admin" {
  entity_name = "terraform-admin"
}

# -----------------------------------------------------------------------------
# KUBERNETES USER ENTITIES
# -----------------------------------------------------------------------------
# Creates Vault identity entities for Kubernetes users
# Links authentication methods to consistent identity across Vault

resource "vault_identity_entity" "kube_admin" {
  name     = "kube-admin-oidc"
  policies = ["kubernetes-policy-test"]
}

resource "vault_identity_entity" "kube_reader" {
  name     = "kube-reader-oidc"
  policies = ["kubernetes-policy-test"]
}

resource "vault_identity_entity_alias" "kube_admin" {
  name           = "kube-admin-oidc"
  mount_accessor = vault_auth_backend.kubernetes_userpass.accessor
  canonical_id   = vault_identity_entity.kube_admin.id
}

# -----------------------------------------------------------------------------
# KUBERNETES ACCESS GROUPS
# -----------------------------------------------------------------------------
# Organizes users into logical groups matching Kubernetes RBAC expectations
# Maps Vault groups to Kubernetes cluster roles and role bindings

resource "vault_identity_group" "kubernetes_users_admin" {
  name = "system:masters"
  type = "internal"

  policies = ["kubernetes-access-oidc-token"]

  member_entity_ids = [
    vault_identity_entity.kube_admin.id,
    data.vault_identity_entity.terraform_admin.id
  ]
}

resource "vault_identity_group" "kubernetes_users_readonly" {
  name = "kubernetes-users-readonly"
  type = "internal"

  policies = ["kubernetes-access-oidc-token"]

  member_entity_ids = [
    vault_identity_entity.kube_reader.id,
  ]
}

# -----------------------------------------------------------------------------
# KUBERNETES ACCESS POLICIES
# -----------------------------------------------------------------------------
# Defines permissions for OIDC token access and Kubernetes authentication
# Controls which users can obtain tokens for cluster access

resource "vault_policy" "kubernetes_access_oidc_token" {
  name = "kubernetes-access-oidc-token"

  policy = <<-EOF
  path "identity/oidc/token/kubernetes-low-layer-oidc-token" {
    capabilities = ["read"]
  }
EOF
}

# =============================================================================
# OPERATIONAL NOTES
# =============================================================================
# 
# User Authentication Flow:
# - Users authenticate to Vault using username/password credentials
# - Successful authentication grants access to OIDC token endpoint
# - Users request OIDC tokens for Kubernetes cluster authentication
# - Kubernetes validates tokens and maps groups to RBAC permissions
# 
# Group Mappings:
# - system:masters: Full cluster administrator privileges (built-in Kubernetes group)
# - kubernetes-users-readonly: Custom group for read-only cluster access
# - Groups appear in OIDC token claims for Kubernetes RBAC integration