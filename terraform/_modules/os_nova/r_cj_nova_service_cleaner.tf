# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# NOVA SERVICE CLEANER CRONJOB
# =============================================================================
# This resource provisions a Kubernetes CronJob that performs Nova service cleanup
# operations on an hourly basis. It ensures stale compute services are removed from
# the database and uses a dependency-aware init container to wait for required
# services and jobs. This job uses OpenStack CLI tools for service management.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Declares the CronJob metadata, including standard Kubernetes labels for lifecycle
# and component tracking. These labels help with monitoring, auditing, and grouping.

resource "kubernetes_cron_job_v1" "nova_service_cleaner" {
  metadata {
    name      = "nova-service-cleaner"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "service-cleaner"
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
          "app.kubernetes.io/component" = "service-cleaner"
        }
      }

      spec {
        template {
          metadata {
            labels = {
              "app.kubernetes.io/name"      = "nova"
              "app.kubernetes.io/instance"  = "openstack-nova"
              "app.kubernetes.io/component" = "service-cleaner"
            }
          }

          spec {
            service_account_name             = "nova-service-cleaner"
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
            # This container waits for required services and jobs before allowing
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
                name = "DEPENDENCY_POD_JSON" 
              }

              env { name = "DEPENDENCY_CUSTOM_RESOURCE" }

              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = true
                run_as_user                = 65534
              }
            }

            # -------------------------------------------------------------------
            # MAIN CONTAINER - NOVA SERVICE CLEANER EXECUTION
            # -------------------------------------------------------------------
            # Executes the Nova service cleaner script to remove stale compute services.

            container {
              name              = "nova-service-cleaner"
              image             = "docker.io/openstackhelm/ceph-config-helper:latest-ubuntu_jammy"
              image_pull_policy = "IfNotPresent"

              command = [
                "/tmp/nova-service-cleaner.sh"
              ]

              # -----------------------------------------------------------------
              # OPENSTACK AUTHENTICATION ENVIRONMENT VARIABLES
              # -----------------------------------------------------------------
              # Credentials sourced from Kubernetes secret for OpenStack API access.

              env {
                name  = "OS_IDENTITY_API_VERSION"
                value = "3"
              }

              env {
                name = "OS_AUTH_URL"
                value_from {
                  secret_key_ref {
                    name = "nova-keystone-user"
                    key  = "OS_AUTH_URL"
                  }
                }
              }

              env {
                name = "OS_REGION_NAME"
                value_from {
                  secret_key_ref {
                    name = "nova-keystone-user"
                    key  = "OS_REGION_NAME"
                  }
                }
              }

              env {
                name = "OS_INTERFACE"
                value_from {
                  secret_key_ref {
                    name = "nova-keystone-user"
                    key  = "OS_INTERFACE"
                  }
                }
              }

              env {
                name = "OS_ENDPOINT_TYPE"
                value_from {
                  secret_key_ref {
                    name = "nova-keystone-user"
                    key  = "OS_INTERFACE"
                  }
                }
              }

              env {
                name = "OS_PROJECT_DOMAIN_NAME"
                value_from {
                  secret_key_ref {
                    name = "nova-keystone-user"
                    key  = "OS_PROJECT_DOMAIN_NAME"
                  }
                }
              }

              env {
                name = "OS_PROJECT_NAME"
                value_from {
                  secret_key_ref {
                    name = "nova-keystone-user"
                    key  = "OS_PROJECT_NAME"
                  }
                }
              }

              env {
                name = "OS_USER_DOMAIN_NAME"
                value_from {
                  secret_key_ref {
                    name = "nova-keystone-user"
                    key  = "OS_USER_DOMAIN_NAME"
                  }
                }
              }

              env {
                name = "OS_USERNAME"
                value_from {
                  secret_key_ref {
                    name = "nova-keystone-user"
                    key  = "OS_USERNAME"
                  }
                }
              }

              env {
                name = "OS_PASSWORD"
                value_from {
                  secret_key_ref {
                    name = "nova-keystone-user"
                    key  = "OS_PASSWORD"
                  }
                }
              }

              env {
                name = "OS_DEFAULT_DOMAIN"
                value_from {
                  secret_key_ref {
                    name = "nova-keystone-user"
                    key  = "OS_DEFAULT_DOMAIN"
                  }
                }
              }

              volume_mount {
                name       = "pod-tmp"
                mount_path = "/tmp"
              }

              volume_mount {
                name       = "nova-bin"
                mount_path = "/tmp/nova-service-cleaner.sh"
                sub_path   = "nova-service-cleaner.sh"
                read_only  = true
              }

              volume_mount {
                name       = "etcnova"
                mount_path = "/etc/nova"
              }

              volume_mount {
                name       = "nova-etc-snippets"
                mount_path = "/etc/nova/nova.conf.d/"
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
            # Define required volumes for tmp runtime, config secrets and cleaner script.

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

            volume {
              name = "nova-etc-snippets"
              projected {
                default_mode = "0644"

                sources {
                  secret {
                    name = "nova-ks-etc"
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}