# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK KEYSTONE RBAC CONFIGURATION LOCALS
# =============================================================================
# Locals for defining RBAC access and operational roles for Keystone components
# Defines service accounts, role definitions, permissions and bindings
# Used to generate Kubernetes RBAC resources for OpenStack Keystone services

# ----------------------------------------------------------------------------- 
# LOCAL COMPUTED VALUES
# ----------------------------------------------------------------------------- 
# Computed configurations for RBAC service accounts, roles, and bindings
# These are transformed for use across Kubernetes resource definitions

locals {

  # ----------------------------------------------------------------------------
  # Base service accounts used by Keystone components
  # Purpose: Defines the complete list of required service accounts used by jobs and workloads
  sa = [
    "openstack-keystone-api",
    "openstack-keystone-rabbit-init",
    "openstack-keystone-db-sync",
    "openstack-keystone-fernet-rotate",
    "openstack-keystone-fernet-setup",
    "openstack-test",
    "openstack-keystone",
    "openstack-keystone-credential-setup",
    "openstack-keystone-credential-rotate",
    "openstack-keystone-bootstrap",
    "openstack-keystone-domain-manage",
    "openstack-keystone-db-init"
  ]

  # ----------------------------------------------------------------------------
  # Role definitions for namespace-scoped access
  # Purpose: Grants access permissions to Keystone components over specific k8s resources
  role = {
    openstack-keystone-api = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-fernet-rotate = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-domain-manage = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-db-sync = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-credential-rotate = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-bootstrap = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints", "jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-openstack-test = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-secrets-keystone-credential-setup = {
      api_groups = [""]
      resources  = ["secrets"]
      verbs      = ["get", "list", "create", "update"]
    },
    openstack-secrets-keystone-credential-rotate = {
      api_groups = [""]
      resources  = ["secrets"]
      verbs      = ["get", "list", "create", "update"]
    },
    openstack-secrets-keystone-fernet-setup = {
      api_groups = [""]
      resources  = ["secrets"]
      verbs      = ["get", "list", "create", "update"]
    },
    openstack-secrets-keystone-fernet-rotate = {
      api_groups = [""]
      resources  = ["secrets"]
      verbs      = ["get", "list", "create", "update"]
    }
  }

  # ----------------------------------------------------------------------------
  # Role bindings mapping service accounts to roles
  # Purpose: Binds service accounts to RBAC roles for component authorization
  role_binding = {
    openstack-keystone-api                         = ["openstack-keystone-api"]
    openstack-keystone-db-sync                     = ["openstack-keystone-db-sync"]
    openstack-keystone-bootstrap                   = ["openstack-keystone-bootstrap"]
    openstack-keystone-domain-manage               = ["openstack-keystone-domain-manage"]
    openstack-keystone-fernet-rotate               = ["openstack-keystone-fernet-rotate"]
    openstack-keystone-credential-rotate           = ["openstack-keystone-credential-rotate"]
    openstack-secrets-keystone-credential-setup    = ["openstack-keystone-credential-setup"]
    openstack-secrets-keystone-credential-rotate   = ["openstack-keystone-credential-rotate"]
    openstack-secrets-keystone-fernet-setup        = ["openstack-keystone-fernet-setup"]
    openstack-secrets-keystone-fernet-rotate       = ["openstack-keystone-fernet-rotate"]
    openstack-keystone-test                        = ["openstack-test"]
  }

  # ----------------------------------------------------------------------------
  # Infrastructure-level RBAC access definitions
  # Purpose: Allows Keystone components to access shared infrastructure (services, endpoints)
  role_infrastructure = {
    openstack-infrastructure-keystone = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-infrastructure-keystone-api = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-infrastructure-keystone-db-sync = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-infrastructure-keystone-db-init = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    }
  }

  # ----------------------------------------------------------------------------
  # Infrastructure-level role bindings
  # Purpose: Binds service accounts to infrastructure access roles across namespaces
  role_binding_infrastructure = {
    openstack-infrastructure-keystone             = ["openstack-keystone"]
    openstack-infrastructure-keystone-api         = ["openstack-keystone-api"]
    openstack-infrastructure-keystone-db-sync     = ["openstack-keystone-db-sync"]
    openstack-infrastructure-keystone-db-init     = ["openstack-keystone-db-init"]
  }

  # ----------------------------------------------------------------------------
  # Keystone credential environment variables
  # Purpose: Environment variables required for Keystone CLI and SDK access
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