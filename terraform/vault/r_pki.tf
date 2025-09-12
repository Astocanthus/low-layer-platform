# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# VAULT PKI ENGINE - INTERNAL RESOURCES CERTIFICATE AUTHORITY
# =============================================================================
# This file configures a PKI infrastructure for internal resources and services
# providing centralized certificate management for non-Kubernetes infrastructure

# -----------------------------------------------------------------------------
# PKI SECRETS ENGINE MOUNT
# -----------------------------------------------------------------------------
# Creates PKI backend for managing internal infrastructure certificates
# Separate from Kubernetes PKI for clear trust domain separation

resource "vault_mount" "pki" {
  path                      = "pki"
  type                      = "pki"
  description               = "PKI Backend for internal ressources"
  max_lease_ttl_seconds     = 315360000
  default_lease_ttl_seconds = 7776000
}

resource "vault_pki_secret_backend_config_urls" "pki_config" {
  backend = vault_mount.pki.path
  issuing_certificates = [
    "https://vault.internal/v1/pki/ca",
  ]
  crl_distribution_points = [
    "https://vault.internal/v1/pki/crl"
  ]
}

# -----------------------------------------------------------------------------
# INTERNAL ROOT CERTIFICATE AUTHORITY
# -----------------------------------------------------------------------------
# Creates root CA for internal infrastructure services and resources
# Provides trust foundation for non-Kubernetes internal communications

resource "vault_pki_secret_backend_root_cert" "pki_low_layer_internal" {
  backend     = vault_mount.pki.path
  issuer_name = "low-layer.internal"
  type        = "internal"
  ttl         = "315360000"

  country      = "FR"
  organization = "Low-layer"
  ou           = "Infrastructure"
  common_name  = "Internal CA"
}

# -----------------------------------------------------------------------------
# INTERNAL SERVICES CERTIFICATE ROLE
# -----------------------------------------------------------------------------
# Configures certificate issuance for internal infrastructure services
# Supports wildcard certificates for flexible service deployment

resource "vault_pki_secret_backend_role" "pki_low_layer_internal_role" {
  backend      = vault_mount.pki.path
  issuer_ref   = vault_pki_secret_backend_root_cert.pki_low_layer_internal.issuer_name
  name         = "low-layer.internal"
  country      = ["FR"]
  organization = ["Low-layer"]
  ou           = ["Infrastructure"]

  max_ttl   = "7776000"
  key_type  = "rsa"
  key_bits  = 2048
  key_usage = ["DigitalSignature", "NonRepudiation", "KeyEncipherment", "DataEncipherment"]
  ext_key_usage = ["ServerAuth"]

  allowed_domains = [
    "internal"
  ]

  allow_any_name              = false
  enforce_hostnames           = false
  allow_wildcard_certificates = true
  allow_bare_domains          = true
  allow_ip_sans               = false
  allow_localhost             = false
  allow_subdomains            = true

  basic_constraints_valid_for_non_ca = true
}

# =============================================================================
# OPERATIONAL NOTES
# =============================================================================
# 
# PKI Architecture:
# - Single-tier CA hierarchy for internal infrastructure services
# - 10-year root certificate lifetime with 90-day leaf certificate rotation
# - RSA-2048 keys for broad compatibility across internal services
# 
# Certificate Role Configuration:
# - Wildcard certificates enabled for flexible service naming
# - Server authentication focus for internal service communication
# - Subdomain support for hierarchical service organization
# 
# Use Cases:
# - Internal web services and APIs
# - Database and message queue TLS connections
# - Monitoring and logging infrastructure
# - CI/CD pipeline service authentication