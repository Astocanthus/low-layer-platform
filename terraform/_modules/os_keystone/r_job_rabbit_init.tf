# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE RABBITMQ INITIALIZATION JOB
# =============================================================================
# This resource provisions a Kubernetes Job used to initialize RabbitMQ settings
# for the OpenStack Keystone service. It configures high availability policies,
# exchanges and queues at startup by running a container with an initialization
# script. The job ensures correct RabbitMQ configuration before Keystone starts.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Identifies the Job with standard Kubernetes labels used for discovery,
# monitoring, and lifecycle tracking. This job is labeled as part of the
# Keystone deployment and specifically handles RabbitMQ initialization.

resource "kubernetes_job" "keystone_rabbit_init" {
  metadata {
    name      = "keystone-rabbit-init"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "rabbit-init"
      "app.kubernetes.io/part-of"    = "openstack"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Controls execution of the Job, including retry behavior and number of pods.
  # The job will retry up to 1000 times until successful.

  spec {
    completions     = 1
    parallelism     = 1
    backoff_limit   = 1000
    completion_mode = "NonIndexed"

    # ---------------------------------------------------------------------------
    # POD TEMPLATE
    # ---------------------------------------------------------------------------
    # Defines the pod behavior for this batch job. This includes service account,
    # restart policy, tolerations, volumes, init containers, and containers.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "keystone"
          "app.kubernetes.io/instance"  = "openstack-keystone"
          "app.kubernetes.io/component" = "rabbit-init"
        }
      }

      spec {
        restart_policy                   = "OnFailure"
        service_account_name             = "openstack-keystone-rabbit-init"
        termination_grace_period_seconds = 30
        dns_policy                       = "ClusterFirst"

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # This job must run on control-plane nodes due to access requirements and
        # is restricted via node selectors and tolerations.

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        node_selector = {
          "openstack-control-plane" = "enabled"
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - RABBITMQ INITIALIZATION SCRIPT
        # -----------------------------------------------------------------------
        # Executes a custom script that applies RabbitMQ policies via the management
        # API using the provided admin connection and default user connection.

        container {
          name              = "rabbit-init"
          image             = "docker.io/rabbitmq:3.13-management"
          image_pull_policy = "IfNotPresent"
          command           = ["/bin/bash", "-c", "/tmp/rabbit-init.sh"]

          env {
            name = "RABBITMQ_ADMIN_CONNECTION"
            value_from {
              secret_key_ref {
                name = "keystone-rabbitmq-admin"
                key  = "RABBITMQ_CONNECTION"
              }
            }
          }

          env {
            name = "RABBITMQ_USER_CONNECTION"
            value_from {
              secret_key_ref {
                name = "keystone-rabbitmq-user"
                key  = "RABBITMQ_CONNECTION"
              }
            }
          }

          env {
            name  = "RABBITMQ_AUXILIARY_CONFIGURATION"
            value = jsonencode({
              policies = [
                {
                  name       = "ha_ttl_keystone"
                  apply-to   = "all"
                  pattern    = "^(?!(amq\\.|reply_)).*"
                  priority   = 0
                  vhost      = "keystone"
                  definition = {
                    "ha-mode"      = "all"
                    "ha-sync-mode" = "automatic"
                    "message-ttl"  = 70000
                  }
                }
              ]
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
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -----------------------------------------------------------------------
        # Ensures required services are available before main container runs.
        # Used to wait on dependent services or Kubernetes objects, but here
        # it is mostly stubbed for compatibility with the entrypoint orchestration.

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

          env { name = "DEPENDENCY_SERVICE" }
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
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Temporary emptyDir volume used for writing temp data, and a configMap
        # volume containing the rabbit-init script executed by the main container.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "rabbit-init-sh"
          config_map {
            name         = "keystone-bin"
            default_mode = "0555"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Ensures operations on this resource use customized timeouts for create,
  # update and delete phases depending on runtime requirements.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}