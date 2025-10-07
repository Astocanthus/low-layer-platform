# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# HORIZON DB SYNC JOB
# =============================================================================
# This resource provisions a Kubernetes Job for performing Horizon database
# synchronization. It ensures required initial operations (migrations, etc.)
# are executed before the Horizon API starts. The init container handles
# dependency ordering, and the main container executes the db-sync script.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Declares job identity and standard app.kubernetes.io labels for observability
# and management. Labels help categorize Horizon components in monitoring and
# automated workflows.

resource "kubernetes_job_v1" "horizon_db_sync" {
  metadata {
    name      = "horizon-db-sync"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "horizon"
      "app.kubernetes.io/instance"   = "openstack-horizon"
      "app.kubernetes.io/component"  = "db-sync"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Sets up backoff behavior, job completion limits, and parallelism model.
  # Ensures the database sync completes successfully with retry logic.

  spec {
    backoff_limit     = 10
    completions       = 1
    parallelism       = 1
    completion_mode   = "NonIndexed"

    # ---------------------------------------------------------------------------
    # POD TEMPLATE
    # ---------------------------------------------------------------------------
    # Full pod specification that includes scheduling rules,
    # volumes, and the init and main container logic.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "horizon"
          "app.kubernetes.io/instance"  = "openstack-horizon"
          "app.kubernetes.io/component" = "db-sync"
        }
      }

      spec {
        service_account_name             = "horizon-db-sync"
        restart_policy                   = "OnFailure"
        termination_grace_period_seconds = 30
        dns_policy                       = "ClusterFirst"

        security_context {
          run_as_user = 42424
        }

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Ensures job runs on control-plane nodes with tolerance.
        # Node selector ensures scheduling to OpenStack management nodes.

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
        # Uses Kubernetes EntryPoint to orchestrate startup dependencies.
        # Waits for required database service and job completion before continuing.

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

          env {
            name  = "DEPENDENCY_JOBS"
            value = "horizon-db-init"
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
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - DB SYNC EXECUTION
        # -----------------------------------------------------------------------
        # Executes the database synchronization script required before
        # horizon API launches. Scripts and config are mounted via volumes.

        container {
          name              = "horizon-db-sync"
          image             = "quay.io/airshipit/horizon:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/db-sync.sh"]

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
            run_as_user                = 0
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

          resources {}

          volume_mount {
            name       = "horizon-etc"
            mount_path = "/etc/openstack-dashboard/local_settings"
            sub_path   = "local_settings"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-bin"
            mount_path = "/tmp/db-sync.sh"
            sub_path   = "db-sync.sh"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-bin"
            mount_path = "/tmp/manage.py"
            sub_path   = "manage.py"
            read_only  = true
          }
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Provides configuration required for sync execution including
        # settings, scripts, and management binaries from secrets/configmaps.

        volume {
          name = "horizon-etc"
          secret {
            secret_name  = "horizon-etc"
            default_mode = "0444"
          }
        }

        volume {
          name = "horizon-bin"
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
  # Controls create/update/delete timeout values using module-level variable.

  wait_for_completion = false

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}