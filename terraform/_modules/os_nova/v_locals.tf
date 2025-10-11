# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK NOVA RBAC CONFIGURATION LOCALS
# =============================================================================
# Locals for defining RBAC access configuration for Nova components
# Defines service accounts, role definitions, namespace bindings, and infra roles
# Used to generate Kubernetes RBAC resources for OpenStack Nova workloads

# -----------------------------------------------------------------------------
# LOCAL COMPUTED VALUES
# -----------------------------------------------------------------------------
# Computed configurations for RBAC service accounts, roles, and bindings
# These are transformed for use across Kubernetes resource definitions

locals {

  # ---------------------------------------------------------------------------
  # Service Account List
  # Purpose: Declares the list of Kubernetes service accounts used by Nova components
  service_accounts = [
    "openstack-nova-cell-setup",
    "openstack-nova-cell-setup-cron",
    "openstack-nova-compute",
    "openstack-nova-conductor",
    "openstack-nova-api-osapi",
    "openstack-nova-api-metadata",
    "openstack-nova-bootstrap",
    "openstack-nova-novncproxy",
    "openstack-nova-scheduler",
    "openstack-nova-service-cleaner",
    "openstack-nova-storage-init",
  ]

  # ---------------------------------------------------------------------------
  # Role Definitions for Namespace Access
  # Purpose: Defines RBAC roles for Nova components within a namespace
  role = {
    openstack-nova-api-metadata = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-nova-api-osapi = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-nova-bootstrap = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-nova-cell-setup = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints", "pods", "jobs"]
      verbs      = ["get", "list"]
    },
    openstack-nova-cell-setup-cron = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints", "pods", "jobs"]
      verbs      = ["get", "list"]
    },
    openstack-nova-compute = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints", "pods", "jobs"]
      verbs      = ["get", "list"]
    },
    openstack-nova-conductor = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints", "pods", "jobs"]
      verbs      = ["get", "list"]
    },
    openstack-nova-novncproxy = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["pods", "jobs"]
      verbs      = ["get", "list"]
    },
    openstack-nova-scheduler = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints", "pods", "jobs"]
      verbs      = ["get", "list"]
    },
    openstack-nova-service-cleaner = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints", "pods", "jobs"]
      verbs      = ["get", "list"]
    },
    openstack-nova-storage-init = {
      api_groups = [""]
      resources  = ["secrets"]
      verbs      = ["get", "create", "update", "patch"]
    }
  }

  # ---------------------------------------------------------------------------
  # Role Bindings to Namespace Roles
  # Purpose: Maps service accounts to namespace Role definitions
  role_binding = {
    openstack-nova-api-metadata      = ["openstack-nova-api-metadata"]
    openstack-nova-api-osapi         = ["openstack-nova-api-osapi"]
    openstack-nova-bootstrap         = ["openstack-nova-bootstrap"]
    openstack-nova-cell-setup        = ["openstack-nova-cell-setup"]
    openstack-nova-cell-setup-cron   = ["openstack-nova-cell-setup-cron"]
    openstack-nova-compute           = ["openstack-nova-compute"]
    openstack-nova-conductor         = ["openstack-nova-conductor"]
    openstack-nova-novncproxy        = ["openstack-nova-novncproxy"]
    openstack-nova-scheduler         = ["openstack-nova-scheduler"]
    openstack-nova-service-cleaner   = ["openstack-nova-service-cleaner"]
    openstack-nova-storage-init      = ["openstack-nova-storage-init"]
  }

  # ---------------------------------------------------------------------------
  # Infrastructure Role Definitions
  # Purpose: Defines access to shared cluster-level infrastructure resources
  role_infrastructure = {
    openstack-infrastructure-nova-api = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    }
  }

  # ---------------------------------------------------------------------------
  # Infrastructure Role Bindings
  # Purpose: Associates Nova service accounts to infrastructure roles
  role_binding_infrastructure = {
    openstack-infrastructure-nova-api = ["openstack-nova-api"]
  }

  # ---------------------------------------------------------------------------
  # Keystone Role Definitions
  # Purpose: Grants nova access to Keystone-exposed resources (e.g., endpoints/services)
  role_keystone = {
    openstack-keystone-nova-scheduler = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    }
  }

  # ---------------------------------------------------------------------------
  # Keystone Role Bindings
  # Purpose: Binds nova components to roles on Keystone services
  role_binding_keystone = {
    openstack-keystone-nova-scheduler = ["openstack-nova-scheduler"]
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