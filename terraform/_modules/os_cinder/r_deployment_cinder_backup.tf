# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# CINDER BACKUP DEPLOYMENT
# =============================================================================
# This Kubernetes Deployment runs the OpenStack Cinder backup service, responsible for
# managing and scheduling volume backups. It is deployed as a standalone process and relies
# on various configuration files, secrets, and coordination between services to safely perform
# backups. This deployment supports HA topology strategies and ensures startup dependencies.

# -----------------------------------------------------------------------------
# DEPLOYMENT METADATA
# -----------------------------------------------------------------------------
# Defines the Deployment name, namespace, and standardized Kubernetes labels.
# Labels follow the app.kubernetes.io convention for component categorization.

resource "kubernetes_deployment" "cinder_backup" {
  metadata {
    name      = "cinder-backup"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "backup"
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
  # Controls rolling deployment strategy and failure history.
  # Backup deployment is non-scalable (replicas = 1) and uses standard rolling behavior.

  spec {
    replicas                  = 1
    revision_history_limit    = 3
    progress_deadline_seconds = 600

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "cinder"
        "app.kubernetes.io/instance"  = "openstack-cinder"
        "app.kubernetes.io/component" = "backup"
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
    # Provides full specification of the backup pod, including placement constraints,
    # containers (init and main), volume mounts, and runtime settings.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "cinder"
          "app.kubernetes.io/instance"  = "openstack-cinder"
          "app.kubernetes.io/component" = "backup"
        }
      }

      spec {
        service_account_name              = "openstack-cinder-backup"
        restart_policy                   = "Always"
        termination_grace_period_seconds = 30
        dns_policy                       = "ClusterFirst"

        # -------------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -------------------------------------------------------------------------
        # Limits pod scheduling to control-plane nodes and prefers spreading pods by hostname.

        node_selector = {
          "openstack-control-plane" = "enabled"
        }

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
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
                    values   = ["backup"]
                  }
                }
              }
            }
          }
        }

        security_context {
          run_as_user = 42424
        }

        # -------------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -------------------------------------------------------------------------
        # Ensures Keystone API and required Cinder jobs are completed before main starts.

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

          resources {}

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"
        }

        # -------------------------------------------------------------------------
        # MAIN CONTAINER - CINDER BACKUP SERVICE
        # -------------------------------------------------------------------------
        # Runs the Cinder backup daemon with custom logic and dependencies.
        # Responsible for managing backup scheduling and interaction with Ceph.

        container {
          name              = "cinder-backup"
          image             = "quay.io/airshipit/cinder:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/cinder-backup.sh"]

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "cinder-tmp"
            mount_path = "/var/lib/cinder/tmp"
          }

          volume_mount {
            name       = "cinder-bin"
            mount_path = "/tmp/cinder-backup.sh"
            sub_path   = "cinder-backup.sh"
            read_only  = true
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
            name       = "etcceph"
            mount_path = "/etc/ceph"
          }

          volume_mount {
            name       = "cinder-coordination"
            mount_path = "/var/lib/cinder/coordination"
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

          security_context {
            read_only_root_filesystem = true
            run_as_user              = 0
          }

          resources {}

          termination_message_path   = "/var/log/termination-log"
          termination_message_policy = "File"
        }

        # -------------------------------------------------------------------------
        # VOLUMES
        # -------------------------------------------------------------------------
        # Declares all volumes used by the pod: emptyDirs, ConfigMaps, and Secrets.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "cinder-tmp"
          empty_dir {}
        }

        volume {
          name = "cinder-etc"
          secret {
            secret_name  = "cinder-etc"
            default_mode = "0444"
          }
        }

        volume {
          name = "cinder-bin"
          config_map {
            name         = "cinder-bin"
            default_mode = "0555"
          }
        }

        volume {
          name = "etcceph"
          empty_dir {}
        }

        volume {
          name = "cinder-coordination"
          empty_dir {}
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Timeout settings for create, update, and delete lifecycle operations.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}