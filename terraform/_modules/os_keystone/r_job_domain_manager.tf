# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE DOMAIN MANAGEMENT JOB
# =============================================================================
# This Job is responsible for ensuring that the Keystone service manages domain
# configuration correctly. It runs a one-off task to create or update domains
# at runtime based on secret credentials and scripts configured in ConfigMaps.
# It leverages init containers for dependency checking and initialization logic
# prior to executing the domain management job logic.

# -----------------------------------------------------------------------------
# JOB METADATA AND LABELS
# -----------------------------------------------------------------------------
# Declares the job metadata including standardized Kubernetes labels for
# observability, ownership, and lifecycle tracking.

resource "kubernetes_job" "keystone_domain_manage" {
  metadata {
    name      = "keystone-domain-manage"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "domain-manage"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Basic job execution parameters, including retry policies and strategy.
  # Ensures the job runs a single time and is not parallelized.

  spec {
    completions     = 1
    parallelism     = 1
    backoff_limit   = 6
    completion_mode = "NonIndexed"

    # ---------------------------------------------------------------------------
    # POD TEMPLATE SPECIFICATION
    # ---------------------------------------------------------------------------
    # Defines how the pod should be created including serviceAccount, containers,
    # volumes, affinity, tolerations, and node placement.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "keystone"
          "app.kubernetes.io/instance"  = "openstack-keystone"
          "app.kubernetes.io/component" = "domain-manage"
        }
      }

      spec {
        service_account_name = "openstack-keystone-domain-manage"
        restart_policy       = "OnFailure"
        dns_policy           = "ClusterFirst"

        # -----------------------------------------------------------------------
        # POD SECURITY CONTEXT
        # -----------------------------------------------------------------------
        # Ensures that pods run as a non-root user for security purposes.

        security_context {
          run_as_user = 42424
        }

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Schedules the pod on OpenStack control plane nodes, tolerates taints.

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
        # Waits for necessary services (keystone-api) to be ready before proceeding.

        init_container {
          name    = "init"
          image   = "quay.io/airshipit/kubernetes-entrypoint:latest-ubuntu_focal"
          command = ["kubernetes-entrypoint"]

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

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 65534
          }

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER - DOMAIN MANAGEMENT BOOTSTRAP
        # -----------------------------------------------------------------------
        # Executes initialization script to prepare environment using admin credentials.

        init_container {
          name    = "keystone-domain-manage-init"
          image   = "quay.io/airshipit/heat:2024.1-ubuntu_jammy"
          command = ["/tmp/domain-manage-init.sh"]

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

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "keystone-bin"
            mount_path = "/tmp/domain-manage-init.sh"
            sub_path   = "domain-manage-init.sh"
            read_only  = true
          }
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - DOMAIN MANAGEMENT TASK
        # -----------------------------------------------------------------------
        # Executes the domain management logic to create/update Keystone domains.

        container {
          name    = "keystone-domain-manage"
          image   = "quay.io/airshipit/keystone:2024.1-ubuntu_jammy"
          command = ["/tmp/domain-manage.sh"]

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

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "etckeystonedomains"
            mount_path = "/etc/keystone/domains"
          }

          volume_mount {
            name       = "etckeystone"
            mount_path = "/etc/keystone"
          }

          volume_mount {
            name       = "keystone-bin"
            mount_path = "/tmp/domain-manage.sh"
            sub_path   = "domain-manage.sh"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-bin"
            mount_path = "/tmp/domain-manage.py"
            sub_path   = "domain-manage.py"
            read_only  = true
          }
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Volumes required by the Job for scripts, tmp data, config and secrets.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "etckeystone"
          empty_dir {}
        }

        volume {
          name = "etckeystonedomains"
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

        volume {
          name = "keystone-fernet-keys"
          secret {
            secret_name  = "keystone-fernet-keys"
            default_mode = "0644"
          }
        }

        volume {
          name = "keystone-credential-keys"
          secret {
            secret_name  = "keystone-credential-keys"
            default_mode = "0644"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Sets timeout durations for create/update/delete actions to prevent hanging.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}