# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# VAULT COMMON IDENTITY CONFIGURATION - APPROLE AUTHENTICATION
# =============================================================================
# This file configures common identity and authentication resources shared
# across multiple services and environments in the LOW-LAYER infrastructure

# -----------------------------------------------------------------------------
# APPROLE AUTHENTICATION BACKEND
# -----------------------------------------------------------------------------
# Enables AppRole authentication method for service-to-service authentication
# Provides secure, automated authentication without human interaction

resource "vault_auth_backend" "approle" {
  type = "approle"
  path = "approle"
}

# -----------------------------------------------------------------------------
# VAULT AGENT APPROLE CONFIGURATION
# -----------------------------------------------------------------------------
# Configures AppRole for Vault Agent deployments across the infrastructure
# Enables automated secret management and certificate lifecycle operations

resource "vault_approle_auth_backend_role" "vault_agent" {
  backend            = vault_auth_backend.approle.path
  role_name          = "vault-agent"
  token_ttl          = 86400
  token_max_ttl      = 259200
  secret_id_ttl      = 0
  secret_id_num_uses = 0
  bind_secret_id     = true
  token_policies = [
    "vault-agent-policy",
    vault_policy.k8s_service_account_policy_operator_k8s_low_layer.name
  ]
}

# =============================================================================
# OPERATIONAL NOTES
# =============================================================================
# 
# AppRole Authentication Flow:
# - Services authenticate using role_id (public) and secret_id (private)
# - Successful authentication grants access tokens with configured policies
# - Token TTL of 24 hours with maximum 72-hour lifetime for security balance
# - Secret IDs have no expiration for long-running service deployments
# 
# Vault Agent Integration:
# - Vault Agent acts as authentication proxy for applications
# - Handles token renewal and secret caching automatically
# - Provides secure secret injection without application awareness