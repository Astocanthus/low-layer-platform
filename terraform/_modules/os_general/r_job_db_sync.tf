# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KUBERNETES JOB FOR OPENSTACK DB SYNCHRONIZATION
# =============================================================================
# This resource defines a Kubernetes Job responsible for executing a DB sync 
# operation for an OpenStack module. It runs once per execution and ensures 
# all database schema migrations or initializations are applied properly 
# before services depending on this state can be started. It includes dependency 
# handling via a dedicated initContainer, and uses multiple volumes and configuration 
# sources to bootstrap correctly.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Includes proper Kubernetes recommended labels to identify and group resources. 
# Labels link this job with the corresponding OpenStack module identity.
# Metadata ensures correct placement in the given namespace and uses consistent 
# naming conventions.

resource "kubernetes_job" "db_sync" {
  metadata {
    name      = "${each.value.module_name}-db-sync"
    namespace = each.value.namespace

    labels = {
      "app.kubernetes.io/name"       = each.value.module_name
      "app.kubernetes.io/instance"   = "openstack-${each.value.module_name}"
      "app.kubernetes.io/component"  = "db-sync"
      "app.kubernetes.io/part-of"    = "openstack"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # This job is configured to run once. If it fails, it will retry up to 10 times.
  # The 'NonIndexed' completion mode is used due to the single-run nature.
  spec {
    backoff_limit   = 10
    completion_mode = "NonIndexed"
    completions     = 1
    parallelism     = 1

    # ---------------------------------------------------------------------------
    # POD TEMPLATE
    # ---------------------------------------------------------------------------
    # Describes how the pod executing the job should be structured including 
    # scheduling, containers, volumes, and lifecycle behavior.
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"       = each.value.module_name
          "app.kubernetes.io/instance"   = "openstack-${each.value.module_name}"
          "app.kubernetes.io/component"  = "db-sync"
          "app.kubernetes.io/part-of"    = "openstack"
        }
      }

      spec {
        restart_policy                   = "OnFailure"
        service_account_name             = "openstack-db-sync"
        termination_grace_period_seconds = 30

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Toleration required to schedule on control plane nodes.
        # Node selector ensures job only runs on appropriate nodes.
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
        # Uses kubernetes-entrypoint to block until critical services and jobs 
        # are ready (e.g., database service and db-init job).
        init_container {
          name                     = "init"
          image                    = "quay.io/airshipit/kubernetes-entrypoint:latest-ubuntu_focal"
          image_pull_policy        = "IfNotPresent"
          command                  = ["kubernetes-entrypoint"]

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
            value = "${each.value.module_name}-db-init"
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
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 65534
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

          resources {}
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - DB SYNC EXECUTION
        # -----------------------------------------------------------------------
        # Executes the db-sync script inside the container built from the 
        # OpenStack service image. It receives config via mounted secrets and 
        # config maps.
        container {
          name                     = "${each.value.module_name}-db-sync"
          image                    = "quay.io/airshipit/${each.value.module_name}:2024.1-ubuntu_jammy"
          image_pull_policy        = "IfNotPresent"
          command                  = ["/bin/bash", "-c", "/tmp/db-sync.sh"]

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
            mount_path = "/etc/${each.value.module_name}"
          }

          volume_mount {
            name       = "db-sync-conf"
            mount_path = "/etc/${each.value.module_name}/${var.module_registry[each.key].conf_file}"
            sub_path   = "${var.module_registry[each.key].conf_file}"
            read_only  = true
          }

          volume_mount {
            name       = "db-sync-conf"
            mount_path = "/etc/${each.value.module_name}/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

          resources {}
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # pod-tmp: scratch space shared between containers
        # db-sync-sh: contains db-sync executable script via config map
        # etc-service: temporary directory used for service config rendering
        # db-sync-conf: contains db configuration loaded from Kubernetes secrets
        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "db-sync-sh"
          config_map {
            name         = "${each.value.module_name}-bin"
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
  # Ensures predictable behavior when job creation, update or deletion stalls.
  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }

  # -----------------------------------------------------------------------------
  # ITERATION CONFIGURATION
  # -----------------------------------------------------------------------------
  # This job is created per OpenStack module configuration using for_each.
  for_each = var.openstack_modules_config
}