# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# RABBITMQ INITIALIZATION JOB
# =============================================================================
# This resource provisions a Kubernetes Job that initializes RabbitMQ
# virtual hosts and policies on the specified OpenStack module. It ensures
# the RabbitMQ service is ready before applying configurations. To do that,
# it leverages an init container to manage dependency ordering and a main
# container to invoke the RabbitMQ setup script.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Defines the Job name, namespace, and standardized Kubernetes labels.
# These labels are used for monitoring, logging, and lifecycle management.

resource "kubernetes_job" "rabbit_init" {
  metadata {
    name      = "${each.value.module_name}-rabbit-init"
    namespace = each.value.namespace

    labels = {
      "app.kubernetes.io/name"       = each.value.module_name
      "app.kubernetes.io/instance"   = "openstack-${each.value.module_name}"
      "app.kubernetes.io/component"  = "rabbit-init"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Controls Pod retry and success behavior.
  # The Job runs once, and retries up to 10 times on failure.

  spec {
    backoff_limit   = 10
    completion_mode = "NonIndexed"
    completions     = 1
    parallelism     = 1

    # ---------------------------------------------------------------------------
    # POD TEMPLATE
    # ---------------------------------------------------------------------------
    # Defines the full Pod spec, including placement, containers, volumes.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"       = each.value.module_name
          "app.kubernetes.io/instance"   = "openstack-${each.value.module_name}"
          "app.kubernetes.io/component"  = "rabbit-init"
          "app.kubernetes.io/managed-by" = "terraform"
          "app.kubernetes.io/part-of"    = "openstack"
        }
      }

      spec {
        restart_policy                    = "OnFailure"
        termination_grace_period_seconds = 30
        service_account_name             = "openstack-rabbit-init"

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Job must run on OpenStack control-plane nodes with appropriate toleration.

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
        # Ensures RabbitMQ service is available before main container starts.

        init_container {
          name             = "init"
          image            = "quay.io/airshipit/kubernetes-entrypoint:latest-ubuntu_focal"
          command          = ["kubernetes-entrypoint"]
          image_pull_policy = "IfNotPresent"

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
            value = "${var.infrastructure_namespace}:rabbitmq"
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

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - RABBITMQ INITIALIZATION
        # -----------------------------------------------------------------------
        # Executes RabbitMQ configuration script inside the container.
        # Communicates with RabbitMQ via environment-provided credentials.

        container {
          name             = "rabbit-init"
          image            = "docker.io/rabbitmq:3.13-management"
          command          = ["/bin/bash", "-c", "/tmp/rabbit-init.sh"]
          image_pull_policy = "IfNotPresent"

          env {
            name = "RABBITMQ_ADMIN_CONNECTION"
            value_from {
              secret_key_ref {
                name = "${each.value.module_name}-rabbitmq-admin"
                key  = "RABBITMQ_CONNECTION"
              }
            }
          }

          env {
            name = "RABBITMQ_USER_CONNECTION"
            value_from {
              secret_key_ref {
                name = "${each.value.module_name}-rabbitmq-user"
                key  = "RABBITMQ_CONNECTION"
              }
            }
          }

          env {
            name  = "RABBITMQ_AUXILIARY_CONFIGURATION"
            value = jsonencode({
              policies = [{
                "apply-to"   = "all"
                definition   = {
                  "ha-mode"      = "all"
                  "ha-sync-mode" = "automatic"
                  "message-ttl"  = 70000
                }
                name     = "ha_ttl_${each.value.module_name}"
                pattern  = "^(?!(amq\\.|reply_)).*"
                priority = 0
                vhost    = "${each.value.module_name}"
              }]
            })
          }

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "rabbit-init-sh"
            mount_path = "/tmp/rabbit-init.sh"
            sub_path   = "rabbit-init.sh"
            read_only  = true
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # - rabbit-init-sh: Provides executable script from ConfigMap
        # - pod-tmp: Temporary space for main container execution

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "rabbit-init-sh"
          config_map {
            name         = "general-bin"
            default_mode = "0555"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Provides access to module-level timeout variable, used for create/update/delete ops.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }

  # -----------------------------------------------------------------------------
  # ITERATION CONFIGURATION FOR EACH OPENSTACK MODULE
  # -----------------------------------------------------------------------------
  # Allows parallel execution of jobs across different modules defined in input map.

  for_each = var.openstack_modules_config
}