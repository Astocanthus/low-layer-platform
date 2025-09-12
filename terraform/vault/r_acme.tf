# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# VAULT ACME SECRETS ENGINE - LET'S ENCRYPT INTEGRATION
# =============================================================================
# This file configures Vault's ACME secrets engine for automated certificate
# management with Let's Encrypt staging and production environments

# -----------------------------------------------------------------------------
# ACME SECRETS ENGINE MOUNT
# -----------------------------------------------------------------------------
# Enables ACME secrets engine for automated SSL/TLS certificate management
# Provides integration with ACME providers like Let's Encrypt

resource "vault_mount" "acme" {
  path        = "acme"
  type        = "acme"
  description = "ACME certificates for Let's Encrypt automation"

  # Certificate lifecycle management
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 31536000
}

# -----------------------------------------------------------------------------
# LET'S ENCRYPT ACCOUNT CONFIGURATIONS  
# -----------------------------------------------------------------------------
# Configures ACME accounts for both staging and production environments
# Uses Route53 DNS provider for domain validation challenges

# Let's Encrypt Staging environment account
# Used for testing and development to avoid rate limits
resource "vault_generic_secret" "letsencrypt_staging_account" {
  path = "acme/accounts/letsencrypt-staging"

  data_json = jsonencode({
    provider                = "route53"
    server_url             = "https://acme-staging-v02.api.letsencrypt.org/directory"
    dns_resolvers          = ["1.1.1.1", "8.8.8.8"]
    contact                = "contact@low-layer.com"
    terms_of_service_agreed = true
  })

  depends_on = [
    vault_mount.acme
  ]
}

# Let's Encrypt Production environment account  
# Used for production certificates with rate limiting considerations
resource "vault_generic_secret" "letsencrypt_prod_account" {
  path = "acme/accounts/letsencrypt-prod"

  data_json = jsonencode({
    provider                = "route53"
    server_url             = "https://acme-v02.api.letsencrypt.org/directory"
    dns_resolvers          = ["1.1.1.1", "8.8.8.8"]
    contact                = "contact@low-layer.com"
    terms_of_service_agreed = true
  })

  depends_on = [
    vault_mount.acme
  ]
}

# -----------------------------------------------------------------------------
# ACME CERTIFICATE ROLES
# -----------------------------------------------------------------------------
# Defines certificate issuance policies for different environments
# Controls domain restrictions and certificate parameters

# Staging environment role for development and testing
# Allows wildcard certificates for low-layer.com subdomains
resource "vault_generic_secret" "staging_role" {
  path = "acme/roles/staging-low-layer"

  data_json = jsonencode({
    account             = "letsencrypt-staging"
    allowed_domains     = "low-layer.com"
    allow_bare_domains  = false
    allow_subdomains    = true
  })

  depends_on = [
    vault_mount.acme,
    vault_generic_secret.letsencrypt_staging_account
  ]
}

# Production environment role for live services
# Same restrictions as staging but uses production Let's Encrypt
resource "vault_generic_secret" "prod_role" {
  path = "acme/roles/prod-low-layer"

  data_json = jsonencode({
    account             = "letsencrypt-prod"
    allowed_domains     = "low-layer.com"
    allow_bare_domains  = false
    allow_subdomains    = true
  })

  depends_on = [
    vault_mount.acme,
    vault_generic_secret.letsencrypt_prod_account
  ]
}

# =============================================================================
# OPERATIONAL NOTES
# =============================================================================
# 
# Certificate Management:
# - Staging certificates are not trusted by browsers (testing only)
# - Production has rate limits: 50 certificates/week per domain
# - Certificates auto-renew when 1/3 of lifetime remains
# - Route53 requires AWS credentials with DNS modification permissions
# 
# Usage Examples:
# - Request staging cert: vault write acme/roles/staging-low-layer/cert common_name="test.low-layer.com"
# - Request prod cert: vault write acme/roles/prod-low-layer/cert common_name="api.low-layer.com"