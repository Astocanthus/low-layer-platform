# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# CINDER SCHEDULER DEPLOYMENT
# =============================================================================
# This resource provisions a Kubernetes Deployment for the OpenStack Cinder
# Scheduler component. It orchestrates volume provisioning workflows and
# decision-making logic for scheduling volume operations. It is a part of the
# control-plane and ensures dependencies and placement are properly handled.

# -----------------------------------------------------------------------------
# DEPLOYMENT METADATA
# -----------------------------------------------------------------------------
# Defines the deployment resource for the `cinder-scheduler` component, including
# standardized labels, annotations, and namespace. Labels follow the app.kubernetes.io
# standard to support service discovery, observability, and operational clarity.

resource "kubernetes_deployment" "cinder_scheduler" {
  metadata {
    name      = "cinder-scheduler"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "scheduler"
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
  # Defines how many pods to run and how to update them safely using a rolling
  # deployment strategy. Limited revision history improves rollback capability.

  spec {
    replicas                  = 1
    progress_deadline_seconds = 600
    revision_history_limit    = 3

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "cinder"
        "app.kubernetes.io/instance"  = "openstack-cinder"
        "app.kubernetes.io/component" = "scheduler"
      }
    }

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = 3
        max_unavailable = 1
      }
    }

    # ---------------------------------------------------------------------------
    # POD TEMPLATE SPECIFICATION
    # ---------------------------------------------------------------------------
    # Describes the pod template used by the deployment, including service account,
    # scheduling, affinity, init containers, and containers with security context.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "cinder"
          "app.kubernetes.io/instance"  = "openstack-cinder"
          "app.kubernetes.io/component" = "scheduler"
        }
      }

      spec {
        service_account_name             = "openstack-cinder-scheduler"
        restart_policy                   = "Always"
        termination_grace_period_seconds = 30
        dns_policy                       = "ClusterFirst"

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Scheduler affinity avoids collocation with other scheduler pods.
        # Node selectors ensure placement on control-plane nodes.

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        node_selector = {
          "openstack-control-plane" = "enabled"
        }

        security_context {
          run_as_user = 42424
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
                    values   = ["scheduler"]
                  }
                }
              }
            }
          }
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -----------------------------------------------------------------------
        # Manages startup ordering for critical services and jobs required
        # by Cinder Scheduler (keystone, database, rabbitmq, etc.)

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
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - CINDER SCHEDULER
        # -----------------------------------------------------------------------
        # Launches the cinder-scheduler service using an external script. This
        # container handles the orchestration logic for Cinder volume scheduling.

        container {
          name              = "cinder-scheduler"
          image             = "quay.io/airshipit/cinder:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/cinder-scheduler.sh"]

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }

          volume_mount {
            mount_path = "/tmp"
            name       = "pod-tmp"
          }

          volume_mount {
            name       = "cinder-bin"
            mount_path = "/tmp/cinder-scheduler.sh"
            sub_path   = "cinder-scheduler.sh"
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
            name       = "cinder-etc"
            mount_path = "/etc/cinder/api-paste.ini"
            sub_path   = "api-paste.ini"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-etc"
            mount_path = "/etc/cinder/policy.yaml"
            sub_path   = "policy.yaml"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-coordination"
            mount_path = "/var/lib/cinder/coordination"
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"
        }

        # -----------------------------------------------------------------------
        # VOLUMES AND STORAGE
        # -----------------------------------------------------------------------
        # Defines volumes for scripts, configuration, ephemeral storage,
        # and cinder coordination directory.

        volume {
          name = "pod-tmp"
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
          name = "cinder-coordination"
          empty_dir {}
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Controls default timeout durations for create/update/delete operations.
  # These values are passed from module or caller context.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}