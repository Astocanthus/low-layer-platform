
# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# TERRAFORM BACKEND CONFIGURATION
# =============================================================================
# Configures remote state storage using HashiCorp Consul for team collaboration
# and state persistence across deployments

terraform {

  # -----------------------------------------------------------------------------
  # CONSUL BACKEND CONFIGURATION
  # -----------------------------------------------------------------------------
  # Uses Consul KV store for centralized state management
  # Provides automatic state locking and team collaboration features

  backend "consul" {
    path    = "states/vault"
    address = "https://consul.internal"
    scheme  = "https"
    lock    = true
    gzip    = true
  }
}

# =============================================================================
# BACKEND CONFIGURATION NOTES
# =============================================================================
#
# State Path Organization:
# - states/backbone/          # Infrastructure backbone components
# - states/vault/             # Infrastructure vault components
# - states/applications/      # Application deployments
# - states/environments/dev/  # Environment-specific states
# - states/environments/prod/ # Production environment states
#
# Security Considerations:
# - Configure Consul ACLs with appropriate permissions
# - Implement TLS client certificates for enhanced security
#
# Backup Strategy:
# - Consul provides built-in replication and backup capabilities
# - Consider periodic state exports: terraform state pull > backup.tfstate
# - Implement automated backup schedules for disaster recovery