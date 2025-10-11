# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# NOVA BOOTSTRAP JOB
# =============================================================================
# This resource provisions a Kubernetes Job that performs initial Nova service
# bootstrap operations. It creates default flavors, security groups, and other
# initial resources required for Nova to function properly. This is a one-time
# setup job that runs during initial deployment.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Declares the Job metadata, including standard Kubernetes labels for lifecycle
# and component tracking. These labels help with monitoring, auditing, and grouping.

resource "kubernetes_job_v1" "nova_bootstrap" {
  metadata {
    name      = "nova-bootstrap"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "bootstrap"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB SPECIFICATION
  # -----------------------------------------------------------------------------
  # Defines the Job behavior including completion requirements and pod template.

  spec {
    completions              = 1
    parallelism              = 1
    backoff_limit            = 1000
    completion_mode          = "NonIndexed"

    # ---------------------------------------------------------------------------
    # POD TEMPLATE SPECIFICATION
    # ---------------------------------------------------------------------------
    # This block defines the pod template that will execute the bootstrap task.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "nova"
          "app.kubernetes.io/instance"  = "openstack-nova"
          "app.kubernetes.io/component" = "bootstrap"
        }
      }

      spec {
        service_account_name             = "nova-bootstrap"
        restart_policy                   = "OnFailure"
        termination_grace_period_seconds = 30

        # -----------------------------------------------------------------------
        # POD SECURITY CONTEXT
        # -----------------------------------------------------------------------
        # Security settings applied at the pod level.

        security_context {
          run_as_user = 42424
        }

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Schedules the pod on OpenStack control plane nodes, tolerates taints.

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        node_selector = {
          "openstack-control-plane" = "enabled"
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -----------------------------------------------------------------------
        # Waits for required services before allowing the main container to execute.

        init_container {
          name              = "init"
          image             = "quay.io/airshipit/kubernetes-entrypoint:latest-ubuntu_focal"
          image_pull_policy = "IfNotPresent"
          command           = ["kubernetes-entrypoint"]

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
            value = "${ var.keystone_namespace }:keystone-api,nova-api"
          }

          env { 
            name = "DEPENDENCY_DAEMONSET" 
          }

          env { 
            name = "DEPENDENCY_CONTAINER" 
          }

          env { 
            name = "DEPENDENCY_POD_JSON" 
          }

          env { name = "DEPENDENCY_CUSTOM_RESOURCE" }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 65534
          }
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - NOVA BOOTSTRAP EXECUTION
        # -----------------------------------------------------------------------
        # Executes the Nova bootstrap script to create initial resources.

        container {
          name              = "bootstrap"
          image             = "quay.io/airshipit/heat:2025.1-ubuntu_noble"
          image_pull_policy = "IfNotPresent"

          command = [
            "/bin/bash",
            "-c",
            "/tmp/bootstrap.sh"
          ]

          # -------------------------------------------------------------------
          # OPENSTACK AUTHENTICATION ENVIRONMENT VARIABLES
          # -------------------------------------------------------------------
          # Admin credentials sourced from Kubernetes secret for OpenStack API access.

          env {
            name  = "OS_IDENTITY_API_VERSION"
            value = "3"
          }

          env {
            name = "OS_AUTH_URL"
            value_from {
              secret_key_ref {
                name = "nova-keystone-admin"
                key  = "OS_AUTH_URL"
              }
            }
          }

          env {
            name = "OS_REGION_NAME"
            value_from {
              secret_key_ref {
                name = "nova-keystone-admin"
                key  = "OS_REGION_NAME"
              }
            }
          }

          env {
            name = "OS_INTERFACE"
            value_from {
              secret_key_ref {
                name = "nova-keystone-admin"
                key  = "OS_INTERFACE"
              }
            }
          }

          env {
            name = "OS_ENDPOINT_TYPE"
            value_from {
              secret_key_ref {
                name = "nova-keystone-admin"
                key  = "OS_INTERFACE"
              }
            }
          }

          env {
            name = "OS_PROJECT_DOMAIN_NAME"
            value_from {
              secret_key_ref {
                name = "nova-keystone-admin"
                key  = "OS_PROJECT_DOMAIN_NAME"
              }
            }
          }

          env {
            name = "OS_PROJECT_NAME"
            value_from {
              secret_key_ref {
                name = "nova-keystone-admin"
                key  = "OS_PROJECT_NAME"
              }
            }
          }

          env {
            name = "OS_USER_DOMAIN_NAME"
            value_from {
              secret_key_ref {
                name = "nova-keystone-admin"
                key  = "OS_USER_DOMAIN_NAME"
              }
            }
          }

          env {
            name = "OS_USERNAME"
            value_from {
              secret_key_ref {
                name = "nova-keystone-admin"
                key  = "OS_USERNAME"
              }
            }
          }

          env {
            name = "OS_PASSWORD"
            value_from {
              secret_key_ref {
                name = "nova-keystone-admin"
                key  = "OS_PASSWORD"
              }
            }
          }

          env {
            name = "OS_DEFAULT_DOMAIN"
            value_from {
              secret_key_ref {
                name = "nova-keystone-admin"
                key  = "OS_DEFAULT_DOMAIN"
              }
            }
          }

          env {
            name  = "WAIT_PERCENTAGE"
            value = "70"
          }

          env {
            name  = "REMAINING_WAIT"
            value = "300"
          }

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "bootstrap-sh"
            mount_path = "/tmp/bootstrap.sh"
            sub_path   = "bootstrap.sh"
            read_only  = true
          }

          volume_mount {
            name       = "etc-service"
            mount_path = "/etc/nova"
          }

          volume_mount {
            name       = "bootstrap-conf"
            mount_path = "/etc/nova/nova.conf"
            sub_path   = "nova.conf"
            read_only  = true
          }

          volume_mount {
            name       = "bootstrap-conf"
            mount_path = "/etc/nova/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Define required volumes for tmp runtime, bootstrap script and configuration.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "etc-service"
          empty_dir {}
        }

        volume {
          name = "bootstrap-sh"
          config_map {
            name         = "nova-bin"
            default_mode = "0555"
          }
        }

        volume {
          name = "bootstrap-conf"
          secret {
            secret_name  = "nova-etc"
            default_mode = "0444"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Ensures operations on this resource use customized timeouts for create,
  # update and delete phases depending on runtime requirements.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}