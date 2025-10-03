# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE DATABASE INITIALIZATION JOB
# =============================================================================
# This resource provisions a Kubernetes Job responsible for initializing the
# Keystone database. It ensures database schemas are created or updated before
# running the API. An init container handles external dependencies like MariaDB
# availability and the main container executes the initialization script.

# -----------------------------------------------------------------------------
# JOB METADATA AND LABELS
# -----------------------------------------------------------------------------
# Defines standardized Kubernetes labels for consistent service and monitoring.
# Also sets the namespace and Job name for scoping and discovery.

resource "kubernetes_job" "keystone_db_init" {
  metadata {
    name      = "keystone-db-init"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "db-init"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Configures the job to run once with high retry tolerance.
  # Uses NonIndexed completion mode for simpler pod tracking.

  spec {
    completions     = 1
    parallelism     = 1
    backoff_limit   = 1000
    completion_mode = "NonIndexed"

    # ---------------------------------------------------------------------------
    # POD TEMPLATE SPECIFICATION
    # ---------------------------------------------------------------------------
    # Full pod template containing containers, volumes, placement, and init logic.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "keystone"
          "app.kubernetes.io/instance"  = "openstack-keystone"
          "app.kubernetes.io/component" = "db-init"
        }
      }

      spec {
        service_account_name             = "openstack-keystone-db-init"
        restart_policy                   = "OnFailure"
        dns_policy                       = "ClusterFirst"
        termination_grace_period_seconds = 30

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Restricts scheduling to control-plane nodes.
        # Ensures control-plane only deployment with required toleration set.

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
        # Waits for the MariaDB service to be available before continuing.
        # Uses the kubernetes-entrypoint utility for dynamic dependency resolution.

        init_container {
          name              = "init"
          image             = "quay.io/airshipit/kubernetes-entrypoint:latest-ubuntu_focal"
          image_pull_policy = "IfNotPresent"
          command           = ["kubernetes-entrypoint"]

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
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
            name  = "DEPENDENCY_DAEMONSET"
            value = ""
          }

          env {
            name  = "DEPENDENCY_CONTAINER"
            value = ""
          }

          env {
            name  = "DEPENDENCY_POD_JSON"
            value = ""
          }

          env {
            name  = "DEPENDENCY_CUSTOM_RESOURCE"
            value = ""
          }

          security_context {
            run_as_user                = 65534
            read_only_root_filesystem  = true
            allow_privilege_escalation = false
          }
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - DB INITIALIZATION
        # -----------------------------------------------------------------------
        # Executes a Python script that initializes Keystone's DB with config specified.
        # Uses secrets for root DB connection and mounts the script and config into file paths.

        container {
          name              = "keystone-db-init-0"
          image             = "quay.io/airshipit/heat:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/db-init.py"]

          env {
            name = "ROOT_DB_CONNECTION"
            value_from {
              secret_key_ref {
                name = "keystone-db-admin"
                key  = "DB_CONNECTION"
              }
            }
          }

          env {
            name  = "OPENSTACK_CONFIG_FILE"
            value = "/etc/keystone/keystone.conf"
          }

          env {
            name  = "OPENSTACK_CONFIG_DB_SECTION"
            value = "database"
          }

          env {
            name  = "OPENSTACK_CONFIG_DB_KEY"
            value = "connection"
          }

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

          volume_mount {
            name       = "etc-service"
            mount_path = "/etc/keystone"
          }

          volume_mount {
            name       = "db-init-conf"
            mount_path = "/etc/keystone/keystone.conf"
            sub_path   = "keystone.conf"
            read_only  = true
          }

          volume_mount {
            name       = "db-init-conf"
            mount_path = "/etc/keystone/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # ConfigMap and Secret volumes for scripts and configuration.
        # Also defines temporary and writable emptyDir volumes.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "db-init-sh"
          config_map {
            name         = "keystone-bin"
            default_mode = "0555"
          }
        }

        volume {
          name = "etc-service"
          empty_dir {}
        }

        volume {
          name = "db-init-conf"
          secret {
            secret_name  = "keystone-etc"
            default_mode = "0444"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Applies global timeouts for job creation, updating, and deletion.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}