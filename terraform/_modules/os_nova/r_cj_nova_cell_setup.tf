# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# NOVA CELL SETUP CRONJOB
# =============================================================================
# This resource provisions a Kubernetes CronJob that performs Nova cell setup
# operations on an hourly basis. It ensures proper cell configuration by running
# setup scripts and uses a dependency-aware init container to wait for required
# services and jobs. This job uses OpenStack Nova tools for cell management.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Declares the CronJob metadata, including standard Kubernetes labels for lifecycle
# and component tracking. These labels help with monitoring, auditing, and grouping.

resource "kubernetes_cron_job_v1" "nova_cell_setup" {
  metadata {
    name      = "nova-cell-setup"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "cell-setup"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Defines the CronJob schedule and execution policy. The job is scheduled to run
  # hourly, with concurrency policy forbidding overlaps and reduced history limits.

  spec {
    schedule                      = "0 */1 * * *"
    concurrency_policy            = "Forbid"
    starting_deadline_seconds     = 600
    failed_jobs_history_limit     = 1
    successful_jobs_history_limit = 3
    suspend                       = false

    # ---------------------------------------------------------------------------
    # POD TEMPLATE SPECIFICATION
    # ---------------------------------------------------------------------------
    # This block defines the JobTemplate which will be executed by the CronJob.
    # It includes pod-level metadata and the full pod spec including init and main containers.

    job_template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "nova"
          "app.kubernetes.io/instance"  = "openstack-nova"
          "app.kubernetes.io/component" = "cell-setup"
        }
      }

      spec {
        template {
          metadata {
            labels = {
              "app.kubernetes.io/name"      = "nova"
              "app.kubernetes.io/instance"  = "openstack-nova"
              "app.kubernetes.io/component" = "cell-setup"
            }
          }

          spec {
            service_account_name             = "nova-cell-setup-cron"
            restart_policy                   = "OnFailure"
            termination_grace_period_seconds = 30

            # -------------------------------------------------------------------
            # POD SECURITY CONTEXT
            # -------------------------------------------------------------------
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

            # -------------------------------------------------------------------
            # INIT CONTAINER - DEPENDENCY MANAGEMENT
            # -------------------------------------------------------------------
            # This container waits for required services, jobs, and pods before allowing
            # the main container to execute.

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
                value = "${ var.infrastructure_namespace }:rabbitmq,${ var.infrastructure_namespace }:mariadb,${ var.keystone_namespace }:keystone-api,nova-api"
              }

              env {
                name  = "DEPENDENCY_JOBS"
                value = "nova-db-sync,nova-rabbit-init"
              }

              env { 
                name = "DEPENDENCY_DAEMONSET" 
              }

              env { 
                name = "DEPENDENCY_CONTAINER" 
              }

              env {
                name  = "DEPENDENCY_POD_JSON"
                value = "[{\"labels\":{\"application\":\"nova\",\"component\":\"compute\"},\"requireSameNode\":false}]"
              }

              env { name = "DEPENDENCY_CUSTOM_RESOURCE" }

              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = true
                run_as_user                = 65534
              }
            }

            # -------------------------------------------------------------------
            # MAIN CONTAINER - NOVA CELL SETUP EXECUTION
            # -------------------------------------------------------------------
            # Executes the Nova cell setup script to configure and manage compute cells.

            container {
              name              = "nova-cell-setup"
              image             = "quay.io/airshipit/nova:2025.1-ubuntu_noble"
              image_pull_policy = "IfNotPresent"

              command = [
                "/tmp/cell-setup.sh"
              ]

              volume_mount {
                name       = "pod-tmp"
                mount_path = "/tmp"
              }

              volume_mount {
                name       = "nova-bin"
                mount_path = "/tmp/cell-setup.sh"
                sub_path   = "cell-setup.sh"
                read_only  = true
              }

              volume_mount {
                name       = "etcnova"
                mount_path = "/etc/nova"
              }

              volume_mount {
                name       = "nova-etc"
                mount_path = "/etc/nova/nova.conf"
                sub_path   = "nova.conf"
                read_only  = true
              }

              volume_mount {
                name       = "nova-etc"
                mount_path = "/etc/nova/logging.conf"
                sub_path   = "logging.conf"
                read_only  = true
              }

              volume_mount {
                name       = "nova-etc"
                mount_path = "/etc/nova/policy.yaml"
                sub_path   = "policy.yaml"
                read_only  = true
              }

              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = true
              }
            }

            # -------------------------------------------------------------------
            # VOLUMES
            # -------------------------------------------------------------------
            # Define required volumes for tmp runtime, config secrets and setup script.

            volume {
              name = "pod-tmp"
              empty_dir {}
            }

            volume {
              name = "etcnova"
              empty_dir {}
            }

            volume {
              name = "nova-etc"
              secret {
                secret_name  = "nova-etc"
                default_mode = "0444"
              }
            }

            volume {
              name = "nova-bin"
              config_map {
                name         = "nova-bin"
                default_mode = "0555"
              }
            }
          }
        }
      }
    }
  }
}