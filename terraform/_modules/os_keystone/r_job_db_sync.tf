# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE DATABASE MIGRATION JOB
# =============================================================================
# This resource defines a Kubernetes Job that performs a database schema
# migration for the OpenStack Keystone service. It ensures proper ordering by
# waiting for all required services and init jobs to complete successfully. The
# job uses init containers for dependency checks and the main container for
# running Keystone’s `db_sync` process.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Defines unique job identity and applies standard Kubernetes labels. Labels
# are used for discovery, monitoring, and resource association in OpenStack.

resource "kubernetes_job" "keystone_db_sync" {
  metadata {
    name      = "keystone-db-sync"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "db-sync"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # A one-shot job with high backoff limit. Completion mode is set to avoid
  # indexed pods, as there's only one required.

  spec {
    completions     = 1
    parallelism     = 1
    backoff_limit   = 1000
    completion_mode = "NonIndexed"

    # ---------------------------------------------------------------------------
    # POD TEMPLATE
    # ---------------------------------------------------------------------------
    # Full pod spec including scheduler hints, init containers, and volumes.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "keystone"
          "app.kubernetes.io/instance"  = "openstack-keystone"
          "app.kubernetes.io/component" = "db-sync"
        }
      }

      spec {
        service_account_name = "openstack-keystone-db-sync"
        restart_policy       = "OnFailure"
        dns_policy           = "ClusterFirst"

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Ensures the pod runs only on allowed OpenStack control-plane nodes.

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
        # Ensures dependent services (like mariadb) and jobs are completed
        # before running the main db-sync container.

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
            name  = "DEPENDENCY_JOBS"
            value = "keystone-db-init,keystone-credential-setup,keystone-fernet-setup"
          }

          security_context {
            run_as_user                = 65534
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - KEYSTONE DB SYNC
        # -----------------------------------------------------------------------
        # Runs the Keystone DB migration process. Uses predefined shell script
        # and config files to complete execution.

        container {
          name              = "keystone-db-sync"
          image             = "quay.io/airshipit/keystone:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/bin/bash", "-c", "/tmp/db-sync.sh"]

          env {
            name  = "OS_BOOTSTRAP_ADMIN_URL"
            value = "https://keystone.low-layer.internal/v3"
          }

          env {
            name  = "OS_BOOTSTRAP_INTERNAL_URL"
            value = "https://keystone-api.${var.namespace}.svc.cluster.local/v3"
          }

          env {
            name  = "OS_BOOTSTRAP_PUBLIC_URL"
            value = "https://keystone.low-layer.com/v3"
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
                  name = kubernetes_secret.keystone_credentials_admin.metadata[0].name
                  key  = env.value
                }
              }
            }
          }

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "db-sync-sh"
            mount_path = "/tmp/db-sync.sh"
            sub_path   = "db-sync.sh"
            read_only  = true
          }

          volume_mount {
            name       = "etc-service"
            mount_path = "/etc/keystone"
          }

          volume_mount {
            name       = "db-sync-conf"
            mount_path = "/etc/keystone/keystone.conf"
            sub_path   = "keystone.conf"
            read_only  = true
          }

          volume_mount {
            name       = "db-sync-conf"
            mount_path = "/etc/keystone/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }

          volume_mount {
            name       = "db-sync-sh"
            mount_path = "/tmp/endpoint-update.py"
            sub_path   = "endpoint-update.py"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-fernet-keys"
            mount_path = "/etc/keystone/fernet-keys/"
            read_only  = true
          }
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Defines ephemeral and persistent configuration volumes used by the pod.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "db-sync-sh"
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
          name = "db-sync-conf"
          secret {
            secret_name  = "keystone-etc"
            default_mode = "0444"
          }
        }

        volume {
          name = "keystone-fernet-keys"
          secret {
            secret_name  = "keystone-fernet-keys"
            default_mode = "0644"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Timeout settings for applying the resource safely.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}