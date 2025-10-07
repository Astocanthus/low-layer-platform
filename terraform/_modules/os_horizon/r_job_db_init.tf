# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# HORIZON DATABASE INITIALIZATION JOB
# =============================================================================
# This resource provisions a Kubernetes Job to initialize the Horizon database.
# The job leverages an init container to coordinate startup dependencies,
# and a main container that executes database initialization logic using a script.
# The container uses credentials provided through secrets and configmaps.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Defines job name, namespace, and standardized Kubernetes labels.
# Labels enable lifecycle tracking, monitoring, and dependency association.

resource "kubernetes_job_v1" "horizon_db_init" {
  metadata {
    name      = "horizon-db-init"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "horizon"
      "app.kubernetes.io/instance"   = "openstack-horizon"
      "app.kubernetes.io/component"  = "db-init"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Configures backoff policy and single-run execution mode of the Job.

  spec {
    backoff_limit     = 10
    completions       = 1
    parallelism       = 1
    completion_mode   = "NonIndexed"

    # ---------------------------------------------------------------------------
    # POD TEMPLATE
    # ---------------------------------------------------------------------------
    # All execution logic is embedded inside a Pod template with scheduling,
    # container definitions, and volume configurations.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"       = "horizon"
          "app.kubernetes.io/instance"   = "openstack-horizon"
          "app.kubernetes.io/component"  = "db-init"
        }
      }

      spec {
        service_account_name              = "horizon-db-init"
        termination_grace_period_seconds = 30
        dns_policy                        = "ClusterFirst"
        restart_policy                    = "OnFailure"

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Ensures execution on OpenStack control-plane nodes only (taints tolerated).

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        node_selector = {
          "openstack-control-plane" = "enabled"
        }

        security_context {}

        # -----------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -----------------------------------------------------------------------
        # Ensures MariaDB service is available before main container starts.

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

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

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
            value = "${var.infrastructure_namespace}:mariadb"
          }

          env { name = "DEPENDENCY_DAEMONSET" }
          env { name = "DEPENDENCY_CONTAINER" }
          env { name = "DEPENDENCY_POD_JSON" }
          env { name = "DEPENDENCY_CUSTOM_RESOURCE" }

          resources {}
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - HORIZON DB INITIALIZER
        # -----------------------------------------------------------------------
        # Enters with database credentials and executes initialization script.

        container {
          name              = "horizon-db-init-0"
          image             = "quay.io/airshipit/heat:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/db-init.py"]

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

          env {
            name = "ROOT_DB_CONNECTION"
            value_from {
              secret_key_ref {
                name = "horizon-db-admin"
                key  = "DB_CONNECTION"
              }
            }
          }

          env {
            name = "DB_CONNECTION"
            value_from {
              secret_key_ref {
                name = "horizon-db-user"
                key  = "DB_CONNECTION"
              }
            }
          }

          resources {}

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "db-init-sh"
            mount_path = "/tmp/db-init.py"
            sub_path   = "db-init.py"
            read_only  = true
          }
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # pod-tmp     : Temporary execution space for container
        # db-init-sh  : Script injected via ConfigMap

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "db-init-sh"
          config_map {
            name         = "horizon-bin"
            default_mode = "0555"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Uses module-level configured timeouts for CRUD operations.

  wait_for_completion = false

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}