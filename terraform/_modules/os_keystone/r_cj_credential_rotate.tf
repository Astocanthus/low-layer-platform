# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE CREDENTIAL ROTATE CRONJOB
# =============================================================================
# This resource provisions a Kubernetes CronJob that rotates Keystone credential keys
# on a monthly basis. It ensures security by automating key rotation and uses a
# dependency-aware init container to wait for the required job (keystone-credential-setup).
# This job uses OpenStack Keystone tools for credential rotation.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Declares the CronJob metadata, including standard Kubernetes labels for lifecycle
# and component tracking. These labels help with monitoring, auditing, and grouping.

resource "kubernetes_cron_job_v1" "keystone_credential_rotate" {
  metadata {
    name      = "keystone-credential-rotate"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "credential-rotate"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Defines the CronJob schedule and execution policy. The job is scheduled to run
  # monthly, with concurrency policy forbidding overlaps and reduced history limits.

  spec {
    schedule                      = "0 0 1 * *"
    concurrency_policy            = "Forbid"
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
          "app.kubernetes.io/name"      = "keystone"
          "app.kubernetes.io/instance"  = "openstack-keystone"
          "app.kubernetes.io/component" = "credential-rotate"
        }
      }

      spec {
        template {
          metadata {
            labels = {
              "app.kubernetes.io/name"      = "keystone"
              "app.kubernetes.io/instance"  = "openstack-keystone"
              "app.kubernetes.io/component" = "credential-rotate"
            }
          }

          spec {
            service_account_name             = "openstack-keystone-credential-rotate"
            restart_policy                   = "OnFailure"
            termination_grace_period_seconds = 30

            # -------------------------------------------------------------------
            # POD SCHEDULING AND PLACEMENT
            # -------------------------------------------------------------------
            # Schedule pod on control-plane nodes to ensure correct isolation and performance.

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
            # This container waits for required jobs before allowing the main container to execute.

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

              env { name = "DEPENDENCY_SERVICE" }
              env {
                name  = "DEPENDENCY_JOBS"
                value = "keystone-credential-setup"
              }
              env { name = "DEPENDENCY_DAEMONSET" }
              env { name = "DEPENDENCY_CONTAINER" }
              env { name = "DEPENDENCY_POD_JSON" }
              env { name = "DEPENDENCY_CUSTOM_RESOURCE" }

              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = true
                run_as_user                = 65534
              }
            }

            # -------------------------------------------------------------------
            # MAIN CONTAINER - CREDENTIAL ROTATE EXECUTION
            # -------------------------------------------------------------------
            # Executes the Keystone credential_rotate command using OpenStack provided script.

            container {
              name              = "keystone-credential-rotate"
              image             = "quay.io/airshipit/keystone:2024.1-ubuntu_jammy"
              image_pull_policy = "IfNotPresent"

              command = [
                "python",
                "/tmp/fernet-manage.py",
                "credential_rotate"
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
                value = "/etc/keystone/credential-keys/"
              }
              env {
                name  = "KEYSTONE_CREDENTIAL_MIGRATE_WAIT"
                value = "120"
              }

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

            # -------------------------------------------------------------------
            # VOLUMES
            # -------------------------------------------------------------------
            # Define required volumes for tmp runtime, config secrets and rotation script.

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