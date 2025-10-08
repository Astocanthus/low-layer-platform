# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# HORIZON SERVICE CONFIGURATION LOCALS
# =============================================================================
# Local values used to configure service accounts, roles, and bindings
# Defines permission rules and RBAC associations for OpenStack Horizon
# Includes definition of access roles for infrastructure and Keystone services

# ----------------------------------------------------------------------------- 
# STANDARD SERVICE ACCOUNTS FOR HORIZON OPERATIONS
# -----------------------------------------------------------------------------
# Purpose: Identifies service accounts used by the Horizon application
# These accounts are granted RBAC roles to access Kubernetes resources

locals {
  service_accounts = [
    "horizon",
    "horizon-db-init",
    "horizon-db-sync",
    "openstack-horizon-test"
  ]

  # ---------------------------------------------------------------------------
  # HORIZON ROLE DEFINITIONS
  # ---------------------------------------------------------------------------
  # Purpose: Defines RBAC roles applied to Horizon operations
  # Structure: Maps role names to RBAC permissions (groups, resources, verbs)

  roles = {
    openstack-horizon = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-horizon-db-sync = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-horizon-test = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    }
  }

  # ---------------------------------------------------------------------------
  # HORIZON ROLE TO SERVICE ACCOUNT BINDINGS
  # ---------------------------------------------------------------------------
  # Purpose: Binds Horizon roles to their respective service accounts
  # Structure: Maps role identifier to list of associated service accounts

  role_bindings = {
    openstack-horizon = [
      "horizon"
    ],
    openstack-horizon-db-sync = [
      "horizon-db-sync"
    ],
    openstack-horizon-test = [
      "openstack-horizon-test"
    ]
  }

  # ---------------------------------------------------------------------------
  # INFRASTRUCTURE SERVICE ACCESS ROLES FOR HORIZON
  # ---------------------------------------------------------------------------
  # Purpose: Grants Horizon access to shared infrastructure services
  # Used for communication with services like MariaDB, etc. across namespaces

  role_infrastructure = {
    openstack-infrastructure-horizon = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-infrastructure-horizon-db-init = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-infrastructure-horizon-db-sync = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    }
  }

  # ---------------------------------------------------------------------------
  # INFRASTRUCTURE ROLE BINDINGS FOR HORIZON
  # ---------------------------------------------------------------------------
  # Purpose: Maps infrastructure roles to Horizon service accounts
  # Enables Horizon components to communicate with shared infrastructure

  role_binding_infrastructure = {
    openstack-infrastructure-horizon = [
      "horizon"
    ],
    openstack-infrastructure-horizon-db-init = [
      "horizon-db-init"
    ],
    openstack-infrastructure-horizon-db-sync = [
      "horizon-db-sync"
    ]
  }

  # ---------------------------------------------------------------------------
  # KEYSTONE SERVICE ACCESS ROLES FOR HORIZON
  # ---------------------------------------------------------------------------
  # Purpose: Grants Horizon access to Keystone service endpoints
  # Used to register dashboard with identity service via cross-namespace access

  keystone_roles = {
    openstack-keystone-horizon = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    }
  }

  # ---------------------------------------------------------------------------
  # KEYSTONE ROLE BINDINGS FOR HORIZON
  # ---------------------------------------------------------------------------
  # Purpose: Maps Keystone access roles to Horizon service account
  # Enables Horizon to retrieve identity-related resources for registration

  keystone_role_bindings = {
    openstack-keystone-horizon = [
      "horizon"
    ]
  }
}