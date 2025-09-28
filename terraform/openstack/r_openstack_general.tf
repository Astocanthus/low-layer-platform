# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# OPENSTACK GENERAL SERVICES CONFIGURATION
# =============================================================================
# Centralized configuration and registration of OpenStack service endpoints
# Manages service catalog entries for all OpenStack components in Keystone

# -----------------------------------------------------------------------------
# OPENSTACK SERVICES CONFIGURATION
# -----------------------------------------------------------------------------
# Centralized configuration for all OpenStack service endpoints

locals {
  openstack_general_config = {
    # Service endpoint domains configuration
    public_domain   = "low-layer.com"
    internal_domain = "low-layer.internal" 
    cluster_domain  = "svc.cluster.local"
    
    # Service configuration mapping
    services = {
      glance = {
        module_name     = "glance"
        service_type    = "image"
        namespace_ref   = kubernetes_namespace.openstack_glance.metadata[0].name
        api_version     = ""
      }
      cinder = {
        module_name     = "cinder"
        service_type    = "volumev3"
        namespace_ref   = kubernetes_namespace.openstack_cinder.metadata[0].name
        api_version     = "/v3/%(project_id)s"
      }
      placement = {
        module_name     = "placement"
        service_type    = "placement"
        namespace_ref   = kubernetes_namespace.openstack_placement.metadata[0].name
        api_version     = ""
      }
      nova = {
        module_name     = "nova"
        service_type    = "compute"
        namespace_ref   = kubernetes_namespace.openstack_nova.metadata[0].name
        api_version     = "/v2.1"
      }
      neutron = {
        module_name     = "neutron"
        service_type    = "network"
        namespace_ref   = kubernetes_namespace.openstack_neutron.metadata[0].name
        api_version     = ""
      }
    }
  }
}

# -----------------------------------------------------------------------------
# OPENSTACK GENERAL SERVICES DEPLOYMENT
# -----------------------------------------------------------------------------
# Service catalog registration and endpoint configuration for all OpenStack services

module "openstack_general" {
  source = "../_modules/os_general"

  # Dynamic service configuration generation
  openstack_modules_config = {
    for service_key, service_config in local.openstack_general_config.services : service_key => {
      module_name  = service_config.module_name
      service_type = service_config.service_type
      public_url   = "https://${service_config.service_name}.${local.openstack_general_config.public_domain}${service_config.api_version}"
      internal_url = "https://${service_config.service_name}-api.${service_config.namespace_ref}.${local.openstack_general_config.cluster_domain}${service_config.api_version}"
      admin_url    = "https://${service_config.service_name}.${local.openstack_general_config.internal_domain}${service_config.api_version}"
      namespace    = service_config.namespace_ref
    }
  }

  # Core infrastructure references
  keystone_namespace       = kubernetes_namespace.openstack_keystone.metadata[0].name
  infrastructure_namespace = kubernetes_namespace.openstack_infrastructure.metadata[0].name

  # Service deployment dependencies
  depends_on = [
    helm_release.openstack_mariadb,
    helm_release.openstack_rabbitmq,
    helm_release.openstack_memcached,
    module.openstack_keystone
  ]
}