# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE SERVICE ENDPOINTS JOB
# =============================================================================
# This resource defines a Kubernetes Job that registers Keystone service 
# endpoints (admin, internal, public) for a given OpenStack module.
# It ensures service endpoint exposure by creating them in Keystone after 
# dependent service and jobs have finished.
# The Job is isolated per module to allow clean integration per namespace 
# and registration context.

resource "kubernetes_job" "ks_endpoints" {
  # -----------------------------------------------------------------------------
  # METADATA AND LABELS
  # -----------------------------------------------------------------------------
  # Provides name, namespace, and consistent labeling for workload identification
  metadata {
    name      = "${each.value.module_name}-ks-endpoints"
    namespace = each.value.namespace
    labels = {
      "app.kubernetes.io/component" = "ks-endpoints"
      "app.kubernetes.io/instance"  = "openstack-${each.value.module_name}"
      "app.kubernetes.io/name"      = "${each.value.module_name}"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Retry strategy, pod completion behavior, job concurrency, and parallelism control
  spec {
    backoff_limit   = 10
    completion_mode = "NonIndexed"
    completions     = 1
    parallelism     = 1

    # -----------------------------------------------------------------------------
    # POD TEMPLATE
    # -----------------------------------------------------------------------------
    template {
      metadata {
        labels = {
          "app.kubernetes.io/component" = "ks-endpoints"
          "app.kubernetes.io/instance"  = "openstack-${each.value.module_name}"
          "app.kubernetes.io/name"      = "${each.value.module_name}"
          "app.kubernetes.io/managed-by" = "terraform"
          "app.kubernetes.io/part-of"    = "openstack"
        }
      }

      spec {
        # -------------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -------------------------------------------------------------------------
        # Ensures job is placed on appropriate control plane nodes only
        dns_policy                       = "ClusterFirst"
        restart_policy                   = "OnFailure"
        service_account_name             = "openstack-ks-endpoints"
        termination_grace_period_seconds = 30
        node_selector = {
          "openstack-control-plane" = "enabled"
        }

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        security_context {}

        # -------------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -------------------------------------------------------------------------
        # Uses kubernetes-entrypoint to wait until required services and jobs are up
        init_container {
          name                     = "init"
          image                    = "quay.io/airshipit/kubernetes-entrypoint:latest-ubuntu_focal"
          image_pull_policy        = "IfNotPresent"
          command                  = ["kubernetes-entrypoint"]

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "metadata.name"
              }
            }
          }

          env {
            name = "NAMESPACE"
            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "metadata.namespace"
              }
            }
          }

          env {
            name  = "INTERFACE_NAME"
            value = "eth0"
          }

          env {
            name  = "PATH"
            value = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/"
          }

          env {
            name  = "DEPENDENCY_SERVICE"
            value = "${var.keystone_namespace}:keystone-api"
          }

          env {
            name  = "DEPENDENCY_JOBS"
            value = "${each.value.module_name}-ks-service"
          }

          env { 
            name = "DEPENDENCY_DAEMONSET"        
            value = "" 
          }

          env { 
            name = "DEPENDENCY_CONTAINER"        
            value = "" 
          }

          env { 
            name = "DEPENDENCY_POD_JSON"         
            value = "" 
          }
          
          env { 
            name = "DEPENDENCY_CUSTOM_RESOURCE"  
            value = "" 
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 65534
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"
        }

        # -------------------------------------------------------------------------
        # MAIN CONTAINERS - KEYSTONE ENDPOINT REGISTRATION
        # -------------------------------------------------------------------------
        # Registers admin/internal/public endpoints in Keystone for the module
        # Uses the same logic per container, differing only by endpoint type and URL

        dynamic "container" {
          for_each = {
            admin    = each.value.admin_url
            internal = each.value.internal_url
            public   = each.value.public_url
          }
          content {
            name                     = "image-ks-endpoints-${container.key}"
            image                    = "quay.io/airshipit/heat:2024.1-ubuntu_jammy"
            image_pull_policy        = "IfNotPresent"
            command                  = ["/bin/bash", "-c", "/tmp/ks-endpoints.sh"]

            env {
              name  = "OS_IDENTITY_API_VERSION"
              value = "3"
            }

            dynamic "env" {
              for_each = local.credential_keystone_env
              content {
                name = env.value
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret.keystone_credentials_admin[each.value.namespace].metadata[0].name
                    key  = env.value
                  }
                }
              }
            }

            env {
              name  = "OS_SVC_ENDPOINT"
              value = container.key
            }

            env {
              name  = "OS_SERVICE_NAME"
              value = each.value.module_name
            }

            env {
              name  = "OS_SERVICE_TYPE"
              value = each.value.service_type
            }

            env {
              name  = "OS_SERVICE_ENDPOINT"
              value = container.value
            }

            volume_mount {
              mount_path = "/tmp"
              name       = "pod-tmp"
            }

            volume_mount {
              mount_path = "/tmp/ks-endpoints.sh"
              name       = "ks-endpoints-sh"
              read_only  = true
              sub_path   = "ks-endpoints.sh"
            }

            volume_mount {
              name       = "${each.value.module_name}-tls-local"
              mount_path = "/etc/ssl/${each.value.module_name}-tls-local/issuing_ca"
              sub_path   = "issuing_ca"
              read_only  = true
            }

            termination_message_path   = "/dev/termination-log"
            termination_message_policy = "File"
          }
        }

        # -------------------------------------------------------------------------
        # VOLUMES
        # -------------------------------------------------------------------------
        # Volumes required for container runtime and configuration script
        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "ks-endpoints-sh"
          config_map {
            name         = "general-bin"
            default_mode = "0555"
          }
        }

        volume {
          name = "${each.value.module_name}-tls-local"
          secret {
            secret_name  = "${each.value.module_name}-tls-local"
            default_mode = "0644"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Configure timeout durations for operations
  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }

  # -----------------------------------------------------------------------------
  # ITERATION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Run this job per OpenStack module defined in input variable
  for_each = var.openstack_modules_config
}