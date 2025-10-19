# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK CINDER RBAC CONFIGURATION LOCALS
# =============================================================================
# Locals for defining RBAC access and operational roles for Cinder components
# Defines service accounts, role definitions, permissions, and RBAC bindings
# Used to generate Kubernetes RBAC resources for OpenStack Cinder services

# -----------------------------------------------------------------------------
# LOCAL COMPUTED VALUES
# -----------------------------------------------------------------------------
# Computed configurations for RBAC service accounts, roles, and bindings
# These are transformed for use across namespace and cross-namespace resources

locals {

  # ---------------------------------------------------------------------------
  # Service Accounts List
  # Purpose: Defines the full list of service accounts used by Cinder jobs and components
  # Usage: Used to generate Kubernetes service accounts and grant RBAC permissions
  sa = [
    "openstack-cinder-backup-storage-init",
    "openstack-cinder-bootstrap",
    "openstack-cinder-clean",
    "openstack-cinder-create-internal-tenant",
    "openstack-cinder-api",
    "openstack-cinder-backup",
    "openstack-cinder-db-sync",
    "openstack-cinder-scheduler",
    "openstack-cinder-storage-init",
    "openstack-cinder-volume",
    "openstack-cinder-volume-usage-audit"
  ]

  # ---------------------------------------------------------------------------
  # RBAC Role Definitions
  # Purpose: Grants Cinder components access to Kubernetes namespaced resources
  # Structure: Maps component name to RBAC rules (api groups, resources, verbs)
  role = {
    openstack-cinder-backup-storage-init = {
      api_groups = [""]
      resources  = ["secrets"]
      verbs      = ["get", "create", "update", "patch"]
    },
    openstack-cinder-clean = {
      api_groups = [""]
      resources  = ["secrets"]
      verbs      = ["get", "delete"]
    },
    openstack-cinder-storage-init = {
      api_groups = [""]
      resources  = ["secrets"]
      verbs      = ["get", "create", "update", "patch"]
    },
    openstack-cinder-api = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-cinder-backup = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints", "jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-cinder-bootstrap = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-cinder-db-sync = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-cinder-scheduler = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints", "jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-cinder-volume = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints", "jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-cinder-volume-usage-audit = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints", "jobs", "pods"]
      verbs      = ["get", "list"]
    }
  }

  # ---------------------------------------------------------------------------
  # RBAC Role Bindings
  # Purpose: Maps role names to the associated Cinder service accounts
  # Structure: Each role name maps to the list of associated service accounts
  role_binding = {
    openstack-cinder-backup-storage-init     = ["openstack-cinder-backup-storage-init"]
    openstack-cinder-clean                   = ["openstack-cinder-clean"]
    openstack-cinder-storage-init            = ["openstack-cinder-storage-init"]
    openstack-cinder-api                     = ["openstack-cinder-api"]
    openstack-cinder-backup                  = ["openstack-cinder-backup"]
    openstack-cinder-bootstrap               = ["openstack-cinder-bootstrap"]
    openstack-cinder-db-sync                 = ["openstack-cinder-db-sync"]
    openstack-cinder-scheduler               = ["openstack-cinder-scheduler"]
    openstack-cinder-volume                  = ["openstack-cinder-volume"]
    openstack-cinder-volume-usage-audit      = ["openstack-cinder-volume-usage-audit"]
  }

  # ---------------------------------------------------------------------------
  # Infrastructure-Level RBAC Roles
  # Purpose: Provides RBAC rights for components to access infrastructure-level resources
  # Usage: Used by Cinder components that interact with shared services/endpoints
  role_infrastructure = {
    openstack-infrastructure-cinder-api = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-infrastructure-cinder-db-sync = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    }
  }

  # ---------------------------------------------------------------------------
  # Infrastructure Role Bindings
  # Purpose: Maps infrastructure roles to the service accounts that require shared access
  # Usage: Cross-namespace service interaction across Cinder infrastructure jobs
  role_binding_infrastructure = {
    openstack-infrastructure-cinder-api      = ["openstack-cinder-api"]
    openstack-infrastructure-cinder-db-sync  = ["openstack-cinder-db-sync"]
  }

  # ---------------------------------------------------------------------------
  # Keystone Service RBAC Roles
  # Purpose: Grants Cinder services access to Keystone-related shared resources
  # Usage: Used by Cinder components requiring resource access to Keystone-discovered endpoints
  role_keystone = {
    openstack-keystone-cinder-scheduler = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-cinder-volume-usage-audit = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-cinder-volume = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-cinder-backup = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-cinder-create-internal-tenant = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-cinder-api = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-cinder-bootstrap = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    }
  }

  # ---------------------------------------------------------------------------
  # Keystone Role Bindings
  # Purpose: Maps Keystone RBAC roles to the relevant Cinder service accounts
  # Usage: Enables individual components to query or interact with Keystone services
  role_binding_keystone = {
    openstack-keystone-cinder-scheduler               = ["openstack-cinder-scheduler"]
    openstack-keystone-cinder-volume-usage-audit      = ["openstack-cinder-volume-usage-audit"]
    openstack-keystone-cinder-volume                  = ["openstack-cinder-volume"]
    openstack-keystone-cinder-backup                  = ["openstack-cinder-backup"]
    openstack-keystone-cinder-create-internal-tenant  = ["openstack-cinder-create-internal-tenant"]
    openstack-keystone-cinder-api                     = ["openstack-cinder-api"]
    openstack-keystone-cinder-bootstrap               = ["openstack-cinder-bootstrap"]
  }

  # ---------------------------------------------------------------------------
  # Keystone Credential Environment Variables
  # Purpose: Defines env vars required for Keystone-based authentication/authorization
  # Usage: Injected into jobs or components to authenticate with Keystone
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