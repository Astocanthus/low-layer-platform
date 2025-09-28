# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK MODULES CONFIGURATION VARIABLES
# =============================================================================
# Variables for OpenStack service modules deployment and RBAC configuration
# Defines namespaces, service accounts, roles and bindings for OpenStack components

# -----------------------------------------------------------------------------
# OPENSTACK MODULES DEPLOYMENT CONFIGURATION
# -----------------------------------------------------------------------------
variable "openstack_modules_config" {
  description = "Configuration map for OpenStack service modules with URL endpoints and namespace assignments"
  type = map(object({
    module_name  = string # OpenStack service module identifier
    service_type = string # Service type classification for OpenStack catalog
    public_url   = string # Public endpoint URL for external access
    internal_url = string # Internal endpoint URL for service-to-service communication
    admin_url    = string # Administrative endpoint URL for management operations
    namespace    = string # Kubernetes namespace for module deployment
  }))
  
  # Validation for Kubernetes namespace naming conventions
  validation {
    condition = alltrue([
      for config in var.openstack_modules_config : can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", config.namespace))
    ])
    error_message = "All namespaces must follow Kubernetes naming conventions (lowercase, alphanumeric, hyphens allowed)."
  }

  # Validation for module name format
  validation {
    condition = alltrue([
      for config in var.openstack_modules_config : length(trimspace(config.module_name)) > 0
    ])
    error_message = "Module name cannot be empty or whitespace only."
  }

  # Validation for service type format
  validation {
    condition = alltrue([
      for config in var.openstack_modules_config : length(trimspace(config.service_type)) > 0
    ])
    error_message = "Service type cannot be empty or whitespace only."
  }

  # Validation for URL format
  validation {
    condition = alltrue([
      for config in var.openstack_modules_config : 
      can(regex("^https?://[0-9a-zA-Z.-]+(:[0-9]+)?(/.*)?$", config.public_url)) &&
      can(regex("^https?://[0-9a-zA-Z.-]+(:[0-9]+)?(/.*)?$", config.internal_url)) &&
      can(regex("^https?://[0-9a-zA-Z.-]+(:[0-9]+)?(/.*)?$", config.admin_url))
    ])
    error_message = "All URLs must be valid HTTP/HTTPS format."
  }
}

# -----------------------------------------------------------------------------
# INFRASTRUCTURE NAMESPACE CONFIGURATION
# -----------------------------------------------------------------------------
variable "infrastructure_namespace" {
  description = "Kubernetes namespace containing shared infrastructure services (RabbitMQ, MariaDB, Memcached)"
  type        = string
  
  # Validation for Kubernetes namespace naming conventions
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.infrastructure_namespace))
    error_message = "Namespace must follow Kubernetes naming conventions (lowercase, alphanumeric, hyphens allowed)."
  }

  # Validation for non-empty namespace
  validation {
    condition     = length(trimspace(var.infrastructure_namespace)) > 0
    error_message = "Infrastructure namespace cannot be empty or whitespace only."
  }
}

# -----------------------------------------------------------------------------
# KEYSTONE NAMESPACE CONFIGURATION
# -----------------------------------------------------------------------------
variable "keystone_namespace" {
  description = "Kubernetes namespace containing OpenStack Keystone identity service"
  type        = string
  
  # Validation for Kubernetes namespace naming conventions
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.keystone_namespace))
    error_message = "Namespace must follow Kubernetes naming conventions (lowercase, alphanumeric, hyphens allowed)."
  }

  # Validation for non-empty namespace
  validation {
    condition     = length(trimspace(var.keystone_namespace)) > 0
    error_message = "Keystone namespace cannot be empty or whitespace only."
  }
}

# -----------------------------------------------------------------------------
# MODULE REGISTRY CONFIGURATION
# -----------------------------------------------------------------------------
variable "module_registry" {
  description = "Registry of OpenStack service modules with their configuration file specifications"
  type = map(object({
    conf_file = string # Configuration file name for the OpenStack service
  }))

  # Default configuration for standard OpenStack services
  default = {
    glance = {
      conf_file = "glance-api.conf"
    }
    cinder = {
      conf_file = "cinder.conf"
    }
    placement = {
      conf_file = "placement.conf"
    }
    nova = {
      conf_file = "nova.conf"
    }
    neutron = {
      conf_file = "neutron.conf"
    }
  }

  # Validation for configuration file naming
  validation {
    condition = alltrue([
      for module_config in var.module_registry : can(regex("^[a-zA-Z0-9._-]+\\.conf$", module_config.conf_file))
    ])
    error_message = "All configuration files must have .conf extension and valid naming."
  }
}

# -----------------------------------------------------------------------------
# TIMEOUT CONFIGURATION
# -----------------------------------------------------------------------------
variable "timeout" {
  description = "Default timeout duration for OpenStack operations and resource provisioning"
  type        = string
  default     = "5m"

  # Validation for timeout format
  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.timeout))
    error_message = "Timeout must be in format: number followed by s (seconds), m (minutes), or h (hours)."
  }

  # Validation for reasonable timeout range
  validation {
    condition = (
      tonumber(regex("[0-9]+", var.timeout)) >= 1 &&
      (
        (endswith(var.timeout, "s") && tonumber(regex("[0-9]+", var.timeout)) <= 3600) ||
        (endswith(var.timeout, "m") && tonumber(regex("[0-9]+", var.timeout)) <= 60) ||
        (endswith(var.timeout, "h") && tonumber(regex("[0-9]+", var.timeout)) <= 24)
      )
    )
    error_message = "Timeout must be reasonable: 1-3600s, 1-60m, or 1-24h."
  }
}

# -----------------------------------------------------------------------------
# LOCAL COMPUTED VALUES
# -----------------------------------------------------------------------------
# Computed configurations derived from input variables for RBAC and service management

locals {
  # OpenStack credential environment variables for service authentication
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

  # Unique namespaces extracted from module configuration
  unique_namespaces = toset([
    for config in var.openstack_modules_config : config.namespace
  ])

  # -----------------------------------------------------------------------------
  # SERVICE ACCOUNT CONFIGURATION
  # -----------------------------------------------------------------------------
  # Standard OpenStack service accounts for various operational tasks
  sa_list = [
    "openstack-db-init",
    "openstack-db-sync",
    "openstack-ks-endpoints",
    "openstack-ks-service",
    "openstack-ks-user",
    "openstack-rabbit-init",
    "openstack-test"
  ]

  # Flattened service account list across all namespaces
  service_accounts = flatten([
    for namespace in local.unique_namespaces : [
      for sa_name in local.sa_list : {
        key       = "${namespace}-${sa_name}"
        namespace = namespace
        sa_name   = sa_name
      }
    ]
  ])

  # -----------------------------------------------------------------------------
  # RBAC ROLE CONFIGURATION FOR NAMESPACES
  # -----------------------------------------------------------------------------
  # Role definitions for OpenStack service operations within namespaces
  role_list = {
    openstack-db-sync = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["jobs", "pods"]
      verbs      = ["get", "list"]
    },  
    openstack-ks-endpoints = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["jobs", "pods"]
      verbs      = ["get", "list"]
    },
    openstack-openstack-test = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    }
  }

  # Flattened role configuration across all namespaces
  roles = flatten([
    for namespace in local.unique_namespaces : [
      for role_name, role_config in local.role_list : {
        key        = "${namespace}-${role_name}"
        namespace  = namespace
        role_name  = role_name
        api_groups = role_config.api_groups
        resources  = role_config.resources
        verbs      = role_config.verbs
      }
    ]
  ])

  # Role binding definitions mapping roles to service accounts
  role_binding_list = {
    openstack-db-sync = [
      "openstack-db-sync"
    ],
    openstack-ks-endpoints = [
      "openstack-ks-endpoints"
    ],
    openstack-test = [
      "openstack-test"
    ]
  }

  # Flattened role bindings across all namespaces
  role_bindings = flatten([
    for namespace in local.unique_namespaces : [
      for role_name, sa_list in local.role_binding_list : {
        key           = "${namespace}-${role_name}"
        namespace     = namespace
        role_name     = role_name
        service_accounts = sa_list
      }
    ]
  ])

  # -----------------------------------------------------------------------------
  # RBAC CONFIGURATION FOR INFRASTRUCTURE SERVICES
  # -----------------------------------------------------------------------------
  # Cross-namespace access roles for infrastructure services
  role_infrastructure = {    
    openstack-infrastructure-services-db-init = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-infrastructure-services-db-sync = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    }
    openstack-infrastructure-services-rabbit-init = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-infrastructure-services-test = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    }
  }

  # Role bindings for infrastructure service access
  role_binding_infrastructure = {
    openstack-infrastructure-services-db-init = [
      "openstack-db-init"
    ],
    openstack-infrastructure-services-db-sync = [
      "openstack-db-sync"
    ],
    openstack-infrastructure-services-rabbit-init = [
      "openstack-rabbit-init"
    ],
    openstack-infrastructure-services-test = [
      "openstack-test"
    ]
  }

  # -----------------------------------------------------------------------------
  # RBAC CONFIGURATION FOR KEYSTONE SERVICES
  # -----------------------------------------------------------------------------
  # Cross-namespace access roles for Keystone identity service
  role_keystone = {    
    openstack-keystone-services-ks-service = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-services-ks-user = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-services-ks-endpoints = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    },
    openstack-keystone-services-test = {
      api_groups = ["", "extensions", "batch", "apps"]
      resources  = ["services", "endpoints"]
      verbs      = ["get", "list"]
    }
  }

  # Role bindings for Keystone service access
  role_binding_keystone = {
    openstack-keystone-services-ks-service = [
      "openstack-ks-service"
    ],
    openstack-keystone-services-ks-user = [
      "openstack-ks-user"
    ],
    openstack-keystone-services-ks-endpoints = [
      "openstack-ks-endpoints"
    ],
    openstack-keystone-services-test = [
      "openstack-test"
    ]
  }
}