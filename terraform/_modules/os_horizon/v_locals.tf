# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK HORIZON RBAC CONFIGURATION LOCALS
# =============================================================================
# Locals for defining RBAC access and operational roles for Horizon components
# Defines service accounts, role definitions, permissions and bindings
# Used to generate Kubernetes RBAC resources for OpenStack Horizon services

# -----------------------------------------------------------------------------
# LOCAL COMPUTED VALUES
# -----------------------------------------------------------------------------
# Computed configurations for RBAC service accounts, roles, and bindings
# These are transformed for use across Kubernetes resource definitions

locals {

  # ---------------------------------------------------------------------------
  # Base service accounts used by Horizon components
  # Purpose: Defines the complete list of required service accounts used by jobs and workloads
  service_accounts = [
    "horizon",
    "horizon-db-init",
    "horizon-db-sync",
    "openstack-horizon-test"
  ]

  # ---------------------------------------------------------------------------
  # Role definitions for namespace-scoped access
  # Purpose: Grants access permissions to Horizon components over specific k8s resources
  rbac_roles = {
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
  # Namespace role bindings
  # Purpose: Binds service accounts to RBAC roles for component authorization
  rbac_role_bindings = {
    openstack-horizon            = ["horizon"]
    openstack-horizon-db-sync    = ["horizon-db-sync"]
    openstack-horizon-test       = ["openstack-horizon-test"]
  }

  # ---------------------------------------------------------------------------
  # Infrastructure-level RBAC access definitions
  # Purpose: Allows Horizon components to access shared infrastructure (services, endpoints)
  rbac_role_infrastructure = {
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
  # Infrastructure-level role bindings
  # Purpose: Binds service accounts to infrastructure access roles across namespaces
  rbac_role_binding_infrastructure = {
    openstack-infrastructure-horizon            = ["horizon"]
    openstack-infrastructure-horizon-db-init    = ["horizon-db-init"]
    openstack-infrastructure-horizon-db-sync    = ["horizon-db-sync"]
  }

  # ---------------------------------------------------------------------------
  # Keystone access roles for Horizon
  # Purpose: Grants Horizon access to Keystone service endpoints
  rbac_keystone_roles = {
    openstack-keystone-horizon = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    }
  }

  # ---------------------------------------------------------------------------
  # Keystone role bindings for Horizon
  # Purpose: Binds Horizon to roles required to query keystone service endpoints
  rbac_keystone_role_bindings = {
    openstack-keystone-horizon = ["horizon"]
  }
}