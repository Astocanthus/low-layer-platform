# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK PLACEMENT CONFIGURATION LOCALS
# =============================================================================
# Locals for defining RBAC access and resource bindings for OpenStack Placement
# Defines service accounts, namespace-scoped roles and permissions, and bindings
# Used to generate Kubernetes RBAC resources for OpenStack Placement components

# -----------------------------------------------------------------------------
# LOCAL COMPUTED VALUES
# -----------------------------------------------------------------------------
# Computed configurations for Placement service RBAC elements in Kubernetes
# These values are later consumed by RBAC generation resources

locals {

  # ---------------------------------------------------------------------------
  # Placement service accounts
  # Purpose: List of Kubernetes service accounts used by Placement components
  service_accounts = [
    "openstack-placement-api"
  ]

  # ---------------------------------------------------------------------------
  # RBAC roles for Placement API access
  # Purpose: Defines permissions over specific Kubernetes resources
  role = {
    openstack-placement-api = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["jobs", "pods"]
      verbs      = ["get", "list"]
    }
  }

  # ---------------------------------------------------------------------------
  # RBAC role bindings
  # Purpose: Binds Placement service accounts to defined roles
  role_bindings = {
    openstack-placement-api = [
      "openstack-placement-api"
    ]
  }

  # ---------------------------------------------------------------------------
  # Keystone credential environment variables
  # Purpose: Required environment variables for Keystone authentication
  credential_keystone_env = [
    "OS_AUTH_URL",
    "OS_USERNAME",
    "OS_PASSWORD",
    "OS_REGION_NAME",
    "OS_USER_DOMAIN_NAME",
    "OS_PROJECT_DOMAIN_NAME",
    "OS_PROJECT_NAME",
    "OS_INTERFACE",
    "OS_ENDPOINT_TYPE",
    "OS_DEFAULT_DOMAIN",
    "OS_CACERT"
  ]
}