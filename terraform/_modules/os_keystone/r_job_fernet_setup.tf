# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE FERNET SETUP JOB
# =============================================================================
# This resource provisions a Kubernetes Job responsible for initializing
# Fernet keys used by the OpenStack Keystone service for token signing.
# Fernet tokens are symmetric and stateless; this setup ensures the proper
# key repository is initialized on first boot or restored when needed.

# -----------------------------------------------------------------------------
# JOB METADATA AND LABELS
# -----------------------------------------------------------------------------
# Defines the job name, namespace, and standardized labels for lifecycle
# management, identification, and logging purposes.

resource "kubernetes_job" "keystone_fernet_setup" {
  metadata {
    name      = "keystone-fernet-setup"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "fernet-setup"
      "app.kubernetes.io/part-of"    = "openstack"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Controls job retry policy and execution mode. Ensures it runs only once
  # without parallel instances and retries on failure up to 6 times.

  spec {
    completions     = 1
    parallelism     = 1
    backoff_limit   = 6
    completion_mode = "NonIndexed"

    # ---------------------------------------------------------------------------
    # POD TEMPLATE SPECIFICATION
    # ---------------------------------------------------------------------------
    # Main Pod template, containing both init logic and fernet initialization.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "keystone"
          "app.kubernetes.io/instance"  = "openstack-keystone"
          "app.kubernetes.io/component" = "fernet-setup"
        }
      }

      spec {
        service_account_name             = "openstack-keystone-fernet-setup"
        restart_policy                   = "OnFailure"
        dns_policy                       = "ClusterFirst"
        termination_grace_period_seconds = 30

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Ensures the job runs on OpenStack control-plane node with toleration.

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

        # -----------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -----------------------------------------------------------------------
        # Waits for prerequisite services and other jobs before executing setup.

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
            value = ""
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
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - FERNET SETUP
        # -----------------------------------------------------------------------
        # Initializes or regenerates the Fernet key set for Keystone token service.

        container {
          name              = "keystone-fernet-setup"
          image             = "quay.io/airshipit/keystone:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["python", "/tmp/fernet-manage.py", "fernet_setup"]

          env {
            name  = "KEYSTONE_USER"
            value = "keystone"
          }

          env {
            name  = "KEYSTONE_GROUP"
            value = "keystone"
          }

          env {
            name  = "KUBERNETES_NAMESPACE"
            value = var.namespace
          }

          env {
            name  = "KEYSTONE_KEYS_REPOSITORY"
            value = "/etc/keystone/fernet-keys/"
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "etckeystone"
            mount_path = "/etc/keystone"
          }

          volume_mount {
            name       = "fernet-keys"
            mount_path = "/etc/keystone/fernet-keys/"
          }

          volume_mount {
            name       = "keystone-etc"
            mount_path = "/etc/keystone/keystone.conf"
            sub_path   = "keystone.conf"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-etc"
            mount_path = "/etc/keystone/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-bin"
            mount_path = "/tmp/fernet-manage.py"
            sub_path   = "fernet-manage.py"
            read_only  = true
          }
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Provides tmpfs, secret config files, and binary scripts needed
        # for keystone initialization.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "etckeystone"
          empty_dir {}
        }

        volume {
          name = "fernet-keys"
          empty_dir {}
        }

        volume {
          name = "keystone-etc"
          secret {
            secret_name  = "keystone-etc"
            default_mode = "0444"
          }
        }

        volume {
          name = "keystone-bin"
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
  # Configures maximum time allowed for job operations from module variable source

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}