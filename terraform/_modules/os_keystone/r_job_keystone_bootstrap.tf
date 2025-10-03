# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE BOOTSTRAP JOB
# =============================================================================
# Initializes the OpenStack Keystone service by performing bootstrap actions.
# This job is run once to configure system entities such as projects, roles,
# and endpoints. It sets up the Keystone service for initial use with required
# credentials and configuration.

# -----------------------------------------------------------------------------
# JOB METADATA AND LABELS
# -----------------------------------------------------------------------------
# Declares resource metadata including name, namespace, and standard application labels
# used for tracking, grouping, and Helm-style resource identification.

resource "kubernetes_job" "keystone_bootstrap" {
  metadata {
    name      = "keystone-bootstrap"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "bootstrap"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Configures job retries, parallelism, and complete mode to ensure successful
  # one-time initialization without concurrent job races.

  spec {
    backoff_limit   = 100
    completions     = 1
    parallelism     = 1
    completion_mode = "NonIndexed"

    # ---------------------------------------------------------------------------
    # POD TEMPLATE
    # ---------------------------------------------------------------------------
    # Full pod specification containing container(s), volumes, and runtime behavior.
    # Ensures the necessary context, bindings, and resources for bootstrap execution.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "keystone"
          "app.kubernetes.io/instance"  = "openstack-keystone"
          "app.kubernetes.io/component" = "bootstrap"
        }
      }

      spec {
        service_account_name = "openstack-keystone-bootstrap"
        restart_policy       = "OnFailure"
        dns_policy           = "ClusterFirst"

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Limits scheduling to control-plane nodes due to privileged setup state.
        # Toleration ensures pod can be placed on tainted nodes.

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
        # Used to block startup of main container until required dependencies
        # (services or earlier jobs) are ready.

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
            value = "keystone-api"
          }

          env {
            name  = "DEPENDENCY_JOBS"
            value = "keystone-domain-manage"
          }

          security_context {
            run_as_user                 = 65534
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - KEYSTONE BOOTSTRAP LOGIC
        # -----------------------------------------------------------------------
        # Main functionality to initialize Keystone entities and API configuration.
        # Relies on external secrets for credentials and mounts configuration
        # and bootstrap scripts.

        container {
          name              = "bootstrap"
          image             = "quay.io/airshipit/heat:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/bin/bash", "-c", "/tmp/bootstrap.sh"]

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
            name       = "bootstrap-sh"
            mount_path = "/tmp/bootstrap.sh"
            sub_path   = "bootstrap.sh"
            read_only  = true
          }

          volume_mount {
            name       = "etc-service"
            mount_path = "/etc/keystone"
          }

          volume_mount {
            name       = "bootstrap-conf"
            mount_path = "/etc/keystone/keystone.conf"
            sub_path   = "keystone.conf"
            read_only  = true
          }

          volume_mount {
            name       = "bootstrap-conf"
            mount_path = "/etc/keystone/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-ca-local"
            mount_path = "/etc/ssl/keystone-ca-local/"
          }
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Declares all required ephemeral and secret volumes. Includes configs,
        # scripts, and CA certificates needed during bootstrap process.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "bootstrap-sh"
          config_map {
            name         = "keystone-bin"
            default_mode = "0555"
          }
        }

        volume {
          name      = "etc-service"
          empty_dir {}
        }

        volume {
          name = "bootstrap-conf"
          secret {
            secret_name  = "keystone-etc"
            default_mode = "0444"
          }
        }

        volume {
          name = "keystone-keystone-admin"
          secret {
            secret_name  = "keystone-keystone-admin"
            default_mode = "0444"
          }
        }

        volume {
          name = "keystone-ca-local"
          secret {
            secret_name  = "keystone-tls-local"
            default_mode = "0644"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Timeout values used for create/update/delete lifecycle operations, referring 
  # to common variable to ensure consistency across resources.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}