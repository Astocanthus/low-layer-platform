# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE FERNET ROTATE CRONJOB
# =============================================================================
# This resource defines a CronJob that rotates Keystone Fernet keys every 12 hours.
# Fernet keys are used to sign and validate tokens. Regular rotation is essential
# to maintain the security of the token system. This job ensures keys are rotated
# and properly managed, including secure init dependencies handling.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Defines CronJob metadata and standardized labels for observability and management
# Labels help identify the workload as belonging to the Keystone identity component.

resource "kubernetes_cron_job_v1" "keystone_fernet_rotate" {
  metadata {
    name      = "keystone-fernet-rotate"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "fernet-rotate"
      "app.kubernetes.io/part-of"    = "openstack"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # -----------------------------------------------------------------------------
  # CRONJOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Job is scheduled every 12 hours. Concurrency is forbidden to avoid overlaps.
  # Failed jobs are limited to 1 and successful ones to 3 for log/history control.

  spec {
    schedule                       = "0 */12 * * *"
    concurrency_policy             = "Forbid"
    failed_jobs_history_limit      = 1
    successful_jobs_history_limit  = 3
    suspend                        = false

    job_template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "keystone"
          "app.kubernetes.io/instance"  = "openstack-keystone"
          "app.kubernetes.io/component" = "fernet-rotate"
        }
      }

      # -------------------------------------------------------------------------
      # POD TEMPLATE SPECIFICATION
      # -------------------------------------------------------------------------
      # Defines pod configuration including containers, volumes, service account.

      spec {
        template {
          metadata {
            labels = {
              "app.kubernetes.io/name"      = "keystone"
              "app.kubernetes.io/instance"  = "openstack-keystone"
              "app.kubernetes.io/component" = "fernet-rotate"
            }
          }

          spec {
            restart_policy                   = "OnFailure"
            termination_grace_period_seconds = 30
            service_account_name             = "openstack-keystone-fernet-rotate"

            # ---------------------------------------------------------------------
            # POD SCHEDULING AND PLACEMENT
            # ---------------------------------------------------------------------
            # Runs on control-plane nodes only. Tolerates taints for scheduling.

            node_selector = {
              "openstack-control-plane" = "enabled"
            }

            toleration {
              key      = "node-role.kubernetes.io/control-plane"
              operator = "Exists"
              effect   = "NoSchedule"
            }

            security_context {
              run_as_user = 42424
            }

            # ---------------------------------------------------------------------
            # INIT CONTAINER - DEPENDENCY MANAGEMENT
            # ---------------------------------------------------------------------
            # Uses kubernetes-entrypoint to wait for fernet-setup job before running.

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
                name = "INTERFACE_NAME" 
                value = "eth0" 
              }

              env { 
                name = "PATH" 
                value = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/" 
              }

              env { 
                name = "DEPENDENCY_JOBS" 
                value = "keystone-fernet-setup" 
              }

              env { 
                name = "DEPENDENCY_SERVICE" 
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

              env { 
                name = "DEPENDENCY_CUSTOM_RESOURCE" 
              }

              resources {}

              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = true
                run_as_user                = 65534
              }

              termination_message_path   = "/dev/termination-log"
              termination_message_policy = "File"
            }

            # ---------------------------------------------------------------------
            # MAIN CONTAINER - KEYSTONE FERNET ROTATION
            # ---------------------------------------------------------------------
            # Executes the fernet_rotate command leveraging script mounted in /tmp
            # Uses Keystone config and keys mounted through secret/configMap.

            container {
              name              = "keystone-fernet-rotate"
              image             = "quay.io/airshipit/keystone:2024.1-ubuntu_jammy"
              image_pull_policy = "IfNotPresent"

              command = [
                "python",
                "/tmp/fernet-manage.py",
                "fernet_rotate"
              ]

              env {
                name  = "KEYSTONE_USER"
                value = "keystone"
              }

              env {
                name  = "KEYSTONE_GROUP"
                value = "keystone"
              }

              env {
                name  = "KUBERNETES_NAMESPACE"
                value = var.namespace
              }

              env {
                name  = "KEYSTONE_KEYS_REPOSITORY"
                value = "/etc/keystone/fernet-keys/"
              }

              resources {}

              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = true
              }

              termination_message_path   = "/dev/termination-log"
              termination_message_policy = "File"

              volume_mount {
                name       = "pod-tmp"
                mount_path = "/tmp"
              }

              volume_mount {
                name       = "etckeystone"
                mount_path = "/etc/keystone"
              }

              volume_mount {
                name       = "keystone-etc"
                mount_path = "/etc/keystone/keystone.conf"
                sub_path   = "keystone.conf"
                read_only  = true
              }

              volume_mount {
                name       = "keystone-etc"
                mount_path = "/etc/keystone/logging.conf"
                sub_path   = "logging.conf"
                read_only  = true
              }

              volume_mount {
                name       = "keystone-bin"
                mount_path = "/tmp/fernet-manage.py"
                sub_path   = "fernet-manage.py"
                read_only  = true
              }
            }

            # ---------------------------------------------------------------------
            # VOLUMES
            # ---------------------------------------------------------------------
            # Temporary space, Keystone config secrets, and management scripts.

            volume {
              name = "pod-tmp"
              empty_dir {}
            }

            volume {
              name = "etckeystone"
              empty_dir {}
            }

            volume {
              name = "keystone-etc"
              secret {
                secret_name  = "keystone-etc"
                default_mode = "0444"
              }
            }

            volume {
              name = "keystone-bin"
              config_map {
                name         = "keystone-bin"
                default_mode = "0555"
              }
            }
          }
        }
      }
    }
  }
}