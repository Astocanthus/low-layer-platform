# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# CINDER VOLUME USAGE AUDIT CRONJOB
# =============================================================================
# This resource defines a Kubernetes CronJob used to periodically run a volume
# usage audit script for OpenStack Cinder. The audit verifies actual volume
# usage and ensures consistency with metadata. The job executes every hour and
# depends on proper readiness of Cinder and Keystone components before starting.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Defines the CronJob name, namespace, and labels for tracking purposes.
# Labels are standardized for identification and monitoring flows.

resource "kubernetes_cron_job_v1" "cinder_volume_usage_audit" {
  metadata {
    name      = "cinder-volume-usage-audit"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "volume-usage-audit"
      "app.kubernetes.io/part-of"    = "openstack"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Configures the execution strategy for the CronJob. Prevents concurrency
  # and keeps limited job history for both failed and successful executions.

  spec {
    concurrency_policy            = "Forbid"
    failed_jobs_history_limit     = 1
    successful_jobs_history_limit = 3
    starting_deadline_seconds     = 600
    suspend                       = false
    schedule                      = "5 * * * *" # Runs every hour at minute 5

    job_template {
      metadata {
        labels = {
          "app.kubernetes.io/name"       = "cinder"
          "app.kubernetes.io/instance"   = "openstack-cinder"
          "app.kubernetes.io/component"  = "volume-usage-audit"
          "app.kubernetes.io/part-of"    = "openstack"
          "app.kubernetes.io/managed-by" = "terraform"
        }
      }

      # -------------------------------------------------------------------------
      # POD TEMPLATE SPECIFICATION
      # -------------------------------------------------------------------------
      # Defines the pod spec used by each job execution. Includes container
      # specification, security context, scheduling details, and volumes.

      spec {
        template {
          metadata {
            labels = {
              "app.kubernetes.io/name"       = "cinder"
              "app.kubernetes.io/instance"   = "openstack-cinder"
              "app.kubernetes.io/component"  = "volume-usage-audit"
              "app.kubernetes.io/part-of"    = "openstack"
              "app.kubernetes.io/managed-by" = "terraform"
            }
          }

          spec {
            service_account_name              = "openstack-cinder-volume-usage-audit"
            restart_policy                    = "OnFailure"
            dns_policy                        = "ClusterFirst"
            termination_grace_period_seconds  = 30

            # ---------------------------------------------------------------------
            # POD SCHEDULING AND SECURITY
            # ---------------------------------------------------------------------
            # Ensure the pod only runs on control-plane nodes.
            # Security context guarantees least privilege execution.

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
            # Ensures dependent services and jobs are available before audit begins.

            init_container {
              name              = "init"
              image             = "quay.io/airshipit/kubernetes-entrypoint:latest-ubuntu_focal"
              image_pull_policy = "IfNotPresent"
              command           = ["kubernetes-entrypoint"]

              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = true
                run_as_user                = 65534
              }

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
                value = "${var.keystone_namespace}:keystone-api,volume-api"
              }

              env {
                name  = "DEPENDENCY_JOBS"
                value = "cinder-db-sync,cinder-ks-user,cinder-ks-endpoints,cinder-rabbit-init"
              }

              env { name = "DEPENDENCY_DAEMONSET" }
              env { name = "DEPENDENCY_CONTAINER" }
              env { name = "DEPENDENCY_POD_JSON" }
              env { name = "DEPENDENCY_CUSTOM_RESOURCE" }

              termination_message_path   = "/dev/termination-log"
              termination_message_policy = "File"
            }

            # ---------------------------------------------------------------------
            # MAIN CONTAINER - USAGE AUDIT SCRIPT
            # ---------------------------------------------------------------------
            # Executes a volume audit script inside the Cinder container image.

            container {
              name              = "cinder-volume-usage-audit"
              image             = "quay.io/airshipit/cinder:2024.1-ubuntu_jammy"
              image_pull_policy = "IfNotPresent"
              command           = ["/tmp/volume-usage-audit.sh"]

              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = true
              }

              volume_mount {
                name       = "pod-tmp"
                mount_path = "/tmp"
              }

              volume_mount {
                name       = "etccinder"
                mount_path = "/etc/cinder"
              }

              volume_mount {
                name       = "cinder-etc"
                mount_path = "/etc/cinder/cinder.conf"
                sub_path   = "cinder.conf"
                read_only  = true
              }

              volume_mount {
                name       = "cinder-etc"
                mount_path = "/etc/cinder/logging.conf"
                sub_path   = "logging.conf"
                read_only  = true
              }

              volume_mount {
                name       = "cinder-bin"
                mount_path = "/tmp/volume-usage-audit.sh"
                sub_path   = "volume-usage-audit.sh"
                read_only  = true
              }

              termination_message_path   = "/dev/termination-log"
              termination_message_policy = "File"
            }

            # ---------------------------------------------------------------------
            # VOLUMES
            # ---------------------------------------------------------------------
            # Defines volumes used by the audit job. Includes runtime space and
            # configuration files.

            volume {
              name = "pod-tmp"
              empty_dir {}
            }

            volume {
              name = "etccinder"
              empty_dir {}
            }

            volume {
              name = "cinder-etc"
              secret {
                secret_name  = "cinder-etc"
                default_mode = "0444"
              }
            }

            volume {
              name = "cinder-bin"
              config_map {
                name         = "cinder-bin"
                default_mode = "0555"
              }
            }
          }
        }
      }
    }
  }
}