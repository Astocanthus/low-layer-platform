# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# VAULT OIDC IDENTITY PROVIDER - KUBERNETES INTEGRATION
# =============================================================================
# This file configures Vault as an OIDC identity provider for Kubernetes
# cluster authentication, enabling secure token-based access control

# -----------------------------------------------------------------------------
# OIDC SERVER CONFIGURATION
# -----------------------------------------------------------------------------
# Configures Vault as an OpenID Connect identity provider
# Provides centralized identity management for Kubernetes authentication

resource "vault_identity_oidc" "oidc_server" {
  issuer = "https://vault.internal"
}

# -----------------------------------------------------------------------------
# OIDC SIGNING KEY CONFIGURATION
# -----------------------------------------------------------------------------
# Creates RSA signing key for OIDC token validation
# Implements key rotation for enhanced security posture

resource "vault_identity_oidc_key" "kubernetes" {
  name               = "kubernetes-low-layer"
  rotation_period    = "86400"
  verification_ttl   = "86400"
  algorithm          = "RS256"
}

# -----------------------------------------------------------------------------
# OIDC ROLE AND TOKEN TEMPLATE
# -----------------------------------------------------------------------------
# Defines OIDC role for Kubernetes authentication with custom token claims
# Templates provide structured identity information for authorization decisions

resource "vault_identity_oidc_role" "kubernetes_token" {
  name      = "kubernetes-low-layer-oidc-token"
  client_id = "kubernetes-low-layer-oidc-token"
  key       = vault_identity_oidc_key.kubernetes.name
  ttl       = "36000"

  template = <<-EOF
  {
    "username": {{identity.entity.name}},
    "groups": {{identity.entity.groups.names}},
    "nbf": {{time.now}}
  }
EOF
}

# -----------------------------------------------------------------------------
# CLIENT AUTHORIZATION CONFIGURATION
# -----------------------------------------------------------------------------
# Associates OIDC role with signing key for token validation
# Ensures only authorized clients can use the signing key

resource "vault_identity_oidc_key_allowed_client_id" "role" {
  key_name          = vault_identity_oidc_key.kubernetes.name
  allowed_client_id = vault_identity_oidc_role.kubernetes_token.client_id
}

# =============================================================================
# OPERATIONAL NOTES
# =============================================================================
# 
# OIDC Token Flow:
# - Vault acts as identity provider for Kubernetes OIDC authentication
# - Tokens contain user identity and group membership claims
# - Kubernetes validates tokens against Vault's public key endpoint
# 
# Key Management:
# - RSA-256 signing keys rotate every 24 hours (86400 seconds)
# - Verification TTL matches rotation period for seamless key rollover
# - Old keys remain valid during verification TTL for zero-downtime rotation