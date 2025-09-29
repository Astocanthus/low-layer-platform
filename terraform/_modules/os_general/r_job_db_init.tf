# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# DATABASE INITIALIZATION JOB FOR OPENSTACK MODULES
# =============================================================================
# This resource defines a Kubernetes Job responsible for initializing
# the database schema of an OpenStack module. It runs a one-shot db-init
# container with pre-checks governed by an init-container that ensures
# all required dependencies are met before execution.
# The Job is created per OpenStack module using for_each on the config map.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Defines metadata and common labeling to support standard observability,
# tracking, and component identification across modules.

resource "kubernetes_job_v1" "db_init" {
  metadata {
    name      = "${each.value.module_name}-db-init"
    namespace = each.value.namespace

    labels = {
      "app.kubernetes.io/name"       = each.value.module_name
      "app.kubernetes.io/component"  = "db-init"
      "app.kubernetes.io/instance"   = "openstack-${each.value.module_name}"
      "app.kubernetes.io/part-of"    = "openstack"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Configures job-level behavior: one completion, non-parallel, fails after 10 retries.

  spec {
    backoff_limit   = 10
    completion_mode = "NonIndexed"
    completions     = 1
    parallelism     = 1

    # -----------------------------------------------------------------------------
    # POD TEMPLATE
    # -----------------------------------------------------------------------------
    # Describes the pod spec for the job, including containers, volumes, and scheduling.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"       = each.value.module_name
          "app.kubernetes.io/component"  = "db-init"
          "app.kubernetes.io/instance"   = "openstack-${each.value.module_name}"
          "app.kubernetes.io/part-of"    = "openstack"
          "app.kubernetes.io/managed-by" = "terraform"
        }
      }

      spec {
        restart_policy                    = "OnFailure"
        termination_grace_period_seconds = 30
        dns_policy                        = "ClusterFirst"
        service_account_name              = "openstack-db-init"

        # -------------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -------------------------------------------------------------------------
        # Job is scheduled to OpenStack control-plane nodes with toleration applied.

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        node_selector = {
          "openstack-control-plane" = "enabled"
        }

        security_context {}

        # -------------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -------------------------------------------------------------------------
        # Ensures the required database services are ready before executing the job.

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
            value = "${var.infrastructure_namespace}:mariadb"
          }

          # Empty dependency envs used for templating purposes
          env { name = "DEPENDENCY_DAEMONSET" }
          env { name = "DEPENDENCY_CONTAINER" }
          env { name = "DEPENDENCY_POD_JSON" }
          env { name = "DEPENDENCY_CUSTOM_RESOURCE" }

          resources {}

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 65534
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"
        }

        # -------------------------------------------------------------------------
        # MAIN CONTAINER - DATABASE INITIALIZATION
        # -------------------------------------------------------------------------
        # Performs the actual DB initialization using Heat image and configuration.

        container {
          name              = "${each.value.module_name}-db-init-0"
          image             = "quay.io/airshipit/heat:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/db-init.py"]

          env {
            name = "ROOT_DB_CONNECTION"
            value_from {
              secret_key_ref {
                name = "${each.value.module_name}-db-admin"
                key  = "DB_CONNECTION"
              }
            }
          }

          env {
            name  = "OPENSTACK_CONFIG_FILE"
            value = "/etc/${each.value.module_name}/${var.module_registry[each.key].conf_file}"
          }

          env {
            name  = "OPENSTACK_CONFIG_DB_SECTION"
            value = "database"
          }

          env {
            name  = "OPENSTACK_CONFIG_DB_KEY"
            value = "connection"
          }

          resources {}

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

          # -----------------------------------------------------------------------
          # VOLUME MOUNTS - DB INIT
          # -----------------------------------------------------------------------
          # Mounts pod temp dir, db-init script, service etc configuration.

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
            mount_path = "/etc/${each.value.module_name}"
          }

          volume_mount {
            name       = "db-init-conf"
            mount_path = "/etc/${each.value.module_name}/${var.module_registry[each.key].conf_file}"
            sub_path   = "${var.module_registry[each.key].conf_file}"
            read_only  = true
          }

          volume_mount {
            name       = "db-init-conf"
            mount_path = "/etc/${each.value.module_name}/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }
        }

        # -------------------------------------------------------------------------
        # VOLUMES
        # -------------------------------------------------------------------------
        # Required volumes: tmp dir, script, config dir, and configuration secrets.
        
        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "db-init-sh"
          config_map {
            name         = "general-bin"
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
            secret_name  = "${each.value.module_name}-etc"
            default_mode = "0444"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Adjustable resource operation timeouts for create/update/delete.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }

  # -----------------------------------------------------------------------------
  # ITERATION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Iterates job definition for each OpenStack module using provided config map.

  for_each = var.openstack_modules_config
}