# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# CINDER VOLUME DEPLOYMENT
# =============================================================================
# Deploys the Cinder volume service component of OpenStack inside Kubernetes.
# This deployment includes dependency management via Kubernetes entrypoint, Ceph-related
# initialization, and customized volume and secret injection. It ensures reliability and 
# proper sequencing of configuration to support Cinder's interaction with other OpenStack
# and storage components.

# -----------------------------------------------------------------------------
# DEPLOYMENT METADATA AND LABELING
# -----------------------------------------------------------------------------
# Defines deployment name, namespace, and labeling for tracking and service association.

resource "kubernetes_deployment" "cinder_volume" {
  metadata {
    name      = "cinder-volume"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "volume"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }

    annotations = {
      "reloader.stakater.com/auto" = "true"
    }
  }

  # -----------------------------------------------------------------------------
  # REPLICA AND STRATEGY CONFIGURATION
  # -----------------------------------------------------------------------------
  # Defines update strategy and pod replica settings with history control.

  spec {
    replicas                   = 1
    progress_deadline_seconds = 600
    revision_history_limit     = 3

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "cinder"
        "app.kubernetes.io/instance"  = "openstack-cinder"
        "app.kubernetes.io/component" = "volume"
      }
    }

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = 3
        max_unavailable = 1
      }
    }

    # -----------------------------------------------------------------------------
    # POD TEMPLATE SPECIFICATION
    # -----------------------------------------------------------------------------
    # Specifies full pod configuration, including init and main containers,
    # affinity rules, toleration, placement constraints, and volumes.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "cinder"
          "app.kubernetes.io/instance"  = "openstack-cinder"
          "app.kubernetes.io/component" = "volume"
        }
      }

      spec {
        service_account_name              = "openstack-cinder-volume"
        restart_policy                    = "Always"
        termination_grace_period_seconds = 30
        dns_policy                        = "ClusterFirst"

        security_context {
          run_as_user = 42424
        }

        # -------------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -------------------------------------------------------------------------
        # Enforces node-level scheduling constraints and recommends diversified placement.

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        node_selector = {
          "openstack-control-plane" = "enabled"
        }

        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 10
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/instance"
                    operator = "In"
                    values   = ["openstack-cinder"]
                  }
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["cinder"]
                  }
                  match_expressions {
                    key      = "app.kubernetes.io/component"
                    operator = "In"
                    values   = ["volume"]
                  }
                }
              }
            }
          }
        }

        # -------------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -------------------------------------------------------------------------
        # Manages service and job readiness before starting the main volume service.

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
            value = "${var.keystone_namespace}:keystone-api,volume-api"
          }

          env {
            name  = "DEPENDENCY_JOBS"
            value = "cinder-db-sync,cinder-ks-user,cinder-ks-endpoints,cinder-rabbit-init"
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

          resources {}
        }

        # -------------------------------------------------------------------------
        # INIT CONTAINER - CEILOMETER COORDINATION VOLUME PERMISSION FIX
        # -------------------------------------------------------------------------
        # Ensures proper ownership on coordination path to support distributed locks.

        init_container {
          name              = "ceph-coordination-volume-perms"
          image             = "quay.io/airshipit/cinder:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["chown", "-R", "cinder:", "/var/lib/cinder/coordination"]

          security_context {
            read_only_root_filesystem = true
            run_as_user               = 0
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

          volume_mount {
            mount_path = "/tmp"
            name       = "pod-tmp"
          }

          volume_mount {
            mount_path = "/var/lib/cinder/coordination"
            name       = "cinder-coordination"
          }

          resources {}
        }

        # -------------------------------------------------------------------------
        # INIT CONTAINER - CONFIGORIZATION AND AUTH SETUP
        # -------------------------------------------------------------------------
        # Retrieves internal tenant credentials and mounts configuration before main service.

        init_container {
          name              = "init-cinder-conf"
          image             = "quay.io/airshipit/heat:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/retrieve-internal-tenant.sh"]

          security_context {
            read_only_root_filesystem = true
            run_as_user               = 0
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

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
                  name = data.kubernetes_secret.keystone_credentials_admin.metadata[0].name
                  key  = env.value
                }
              }
            }
          }

          env {
            name  = "INTERNAL_PROJECT_NAME"
            value = "internal_cinder"
          }

          env {
            name  = "INTERNAL_USER_NAME"
            value = "internal_cinder"
          }

          env {
            name = "SERVICE_OS_REGION_NAME"
            value_from {
              secret_key_ref {
                name = "keystone-credentials-user"
                key  = "OS_REGION_NAME"
              }
            }
          }

          env {
            name = "SERVICE_OS_PROJECT_DOMAIN_NAME"
            value_from {
              secret_key_ref {
                name = "keystone-credentials-user"
                key  = "OS_PROJECT_DOMAIN_NAME"
              }
            }
          }

          env {
            name = "SERVICE_OS_PROJECT_NAME"
            value_from {
              secret_key_ref {
                name = "keystone-credentials-user"
                key  = "OS_PROJECT_NAME"
              }
            }
          }

          env {
            name = "SERVICE_OS_USER_DOMAIN_NAME"
            value_from {
              secret_key_ref {
                name = "keystone-credentials-user"
                key  = "OS_USER_DOMAIN_NAME"
              }
            }
          }

          env {
            name = "SERVICE_OS_USERNAME"
            value_from {
              secret_key_ref {
                name = "keystone-credentials-user"
                key  = "OS_USERNAME"
              }
            }
          }

          env {
            name = "SERVICE_OS_PASSWORD"
            value_from {
              secret_key_ref {
                name = "keystone-credentials-user"
                key  = "OS_PASSWORD"
              }
            }
          }

          volume_mount {
            mount_path = "/tmp"
            name       = "pod-tmp"
          }

          volume_mount {
            mount_path = "/tmp/retrieve-internal-tenant.sh"
            name       = "cinder-bin"
            read_only  = true
            sub_path   = "retrieve-internal-tenant.sh"
          }

          volume_mount {
            mount_path = "/tmp/pod-shared"
            name       = "pod-shared"
          }

          volume_mount {
            name       = "cinder-tls-local"
            mount_path = "/etc/ssl/cinder-tls-local/issuing_ca"
            sub_path   = "issuing_ca"
            read_only  = true
          }

          resources {}
        }

        # -------------------------------------------------------------------------
        # MAIN CONTAINER - CINDER VOLUME SERVICE
        # -------------------------------------------------------------------------
        # Main execution of the Cinder volume process. Includes dependencies on config, etc.

        container {
          name              = "cinder-volume"
          image             = "quay.io/airshipit/cinder:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/cinder-volume.sh"]

          security_context {
            read_only_root_filesystem = true
          }

          termination_message_path   = "/var/log/termination-log"
          termination_message_policy = "File"

          volume_mount {
            mount_path = "/tmp"
            name       = "pod-tmp"
          }

          volume_mount {
            mount_path = "/var/lib/cinder"
            name       = "pod-var-cinder"
          }

          volume_mount {
            mount_path = "/tmp/cinder-volume.sh"
            name       = "cinder-bin"
            sub_path   = "cinder-volume.sh"
            read_only  = true
          }

          volume_mount {
            mount_path = "/tmp/pod-shared"
            name       = "pod-shared"
          }

          volume_mount {
            mount_path = "/var/lib/cinder/conversion"
            name       = "cinder-conversion"
          }

          volume_mount {
            name       = "cinder-etc"
            mount_path = "/etc/cinder/cinder.conf"
            sub_path   = "cinder.conf"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-etc"
            mount_path = "/etc/cinder/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-etc"
            mount_path = "/etc/cinder/conf/backends.conf"
            sub_path   = "backends.conf"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-etc"
            mount_path = "/etc/cinder/rootwrap.conf"
            sub_path   = "rootwrap.conf"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-etc"
            mount_path = "/etc/cinder/rootwrap.d/volume.filters"
            sub_path   = "volume.filters"
            read_only  = true
          }

          resources {}
        }

        # -------------------------------------------------------------------------
        # VOLUMES AND STORAGE DEFINITIONS
        # -------------------------------------------------------------------------
        # Declares all volume sources including secrets, emptyDir and configMap mounts.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "pod-var-cinder"
          empty_dir {}
        }

        volume {
          name = "pod-shared"
          empty_dir {}
        }

        volume {
          name = "cinder-conversion"
          empty_dir {}
        }

        volume {
          name = "cinder-coordination"
          empty_dir {}
        }

        volume {
          name = "etcceph"
          empty_dir {}
        }

        volume {
          name = "cinder-bin"
          config_map {
            name         = "cinder-bin"
            default_mode = "0555"
          }
        }

        volume {
          name = "cinder-etc"
          secret {
            secret_name  = "cinder-etc"
            default_mode = "0444"
          }
        }

        volume {
          name = "cinder-tls-local"
          secret {
            secret_name  = "cinder-tls-local"
            default_mode = "0644"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Propagates module-level timeout for create/update/delete lifecycle operations.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}