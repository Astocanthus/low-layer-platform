# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# GLANCE STORAGE INITIALIZATION JOB
# =============================================================================
# This Kubernetes Job initializes the storage configuration for the Glance
# image service. It's a one-time task responsible for provisioning required
# Ceph configuration and mounting volumes into the Glance pod filesystem.
# It ensures storage dependencies are configured prior to Glance usage.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Sets the Job name, namespace and applies consistent Kubernetes application
# labels for discoverability, monitoring, and management integration.

resource "kubernetes_job" "glance_storage_init" {
  metadata {
    name      = "glance-storage-init"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "glance"
      "app.kubernetes.io/instance"   = "openstack-glance"
      "app.kubernetes.io/component"  = "storage-init"
      "app.kubernetes.io/part-of"    = "openstack"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Configures backoff policy, completion count and parallelism. This prevents the
  # job from retrying indefinitely and ensures it runs exactly once.

  spec {
    backoff_limit   = 10
    completion_mode = "NonIndexed"
    completions     = 1
    parallelism     = 1

    # ---------------------------------------------------------------------------
    # POD TEMPLATE
    # ---------------------------------------------------------------------------
    # Defines Pod specification with init and main containers, required volumes,
    # placement constraints, and shutdown policy.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"       = "glance"
          "app.kubernetes.io/instance"   = "openstack-glance"
          "app.kubernetes.io/component"  = "storage-init"
        }
      }

      spec {
        restart_policy                   = "OnFailure"
        service_account_name             = "openstack-glance-storage-init"
        termination_grace_period_seconds = 30

        security_context {
          run_as_user = 42424
        }

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Job execution is constrained to control-plane nodes using scheduling
        # tolerations and node selectors.

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
        # Ensures that prerequisite Kubernetes jobs (e.g. user setup) are complete
        # prior to running storage configuration logic.

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
            value = ""
          }

          env {
            name  = "DEPENDENCY_JOBS"
            value = "glance-ks-user"
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
        # MAIN CONTAINER - STORAGE INITIALIZER
        # -----------------------------------------------------------------------
        # Executes the storage initialization script using Ceph helper image.
        # Loads Keystone credentials from secret and Glance volumes for Ceph config.

        container {
          name              = "glance-storage-init"
          image             = "docker.io/openstackhelm/ceph-config-helper:latest-ubuntu_xenial"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/storage-init.sh"]

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
            name  = "STORAGE_BACKEND"
            value = "xpvc"
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
                  name = data.kubernetes_secret.keystone_credentials_user.metadata[0].name
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
            name       = "glance-bin"
            mount_path = "/tmp/storage-init.sh"
            sub_path   = "storage-init.sh"
            read_only  = true
          }

          volume_mount {
            name       = "glance-tls-local"
            mount_path = "/etc/ssl/glance-tls-local/issuing_ca"
            sub_path   = "issuing_ca"
            read_only  = true
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

          resources {}
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Runtime, configuration and TLS volumes used by containers. Scripts are loaded
        # via ConfigMap, TLS CA via Secret, and Pod temporary storage is ephemeral.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "glance-bin"
          config_map {
            name         = "glance-bin"
            default_mode = "0555"
          }
        }

        volume {
          name = "glance-tls-local"
          secret {
            secret_name  = "glance-tls-local"
            default_mode = "0644"
          }
        }
      }
    }
  }
}