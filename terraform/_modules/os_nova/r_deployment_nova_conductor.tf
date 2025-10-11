# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# NOVA CONDUCTOR DEPLOYMENT
# =============================================================================
# This resource provisions a Kubernetes Deployment that runs the Nova Conductor
# service. The conductor service handles database interactions and long-running
# tasks on behalf of compute nodes, providing a security layer between compute
# nodes and the database. It includes RPC-based health probing for reliable
# service monitoring.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Declares the Deployment metadata, including standard Kubernetes labels for
# lifecycle and component tracking. These labels help with monitoring, auditing,
# and grouping.

resource "kubernetes_deployment_v1" "nova_conductor" {
  metadata {
    name      = "nova-conductor"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "conductor"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # DEPLOYMENT SPECIFICATION
  # -----------------------------------------------------------------------------
  # Defines the Deployment behavior including replicas, update strategy, and
  # pod template.

  spec {
    replicas                  = 1
    revision_history_limit    = 3
    progress_deadline_seconds = 600

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "nova"
        "app.kubernetes.io/instance"  = "openstack-nova"
        "app.kubernetes.io/component" = "conductor"
      }
    }

    # ---------------------------------------------------------------------------
    # UPDATE STRATEGY
    # ---------------------------------------------------------------------------
    # Rolling update with surge of 3 and max 1 pod unavailable.

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
    # This block defines the pod template for the deployment.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "nova"
          "app.kubernetes.io/instance"  = "openstack-nova"
          "app.kubernetes.io/component" = "conductor"
        }
      }

      spec {
        service_account_name             = "nova-conductor"
        restart_policy                   = "Always"
        termination_grace_period_seconds = 30

        # -----------------------------------------------------------------------
        # POD SECURITY CONTEXT
        # -----------------------------------------------------------------------
        # Security settings applied at the pod level.

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
        # POD ANTI-AFFINITY
        # -----------------------------------------------------------------------
        # Prefers spreading pods across different nodes for high availability.

        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 10
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"

                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["nova"]
                  }
                  match_expressions {
                    key      = "app.kubernetes.io/instance"
                    operator = "In"
                    values   = ["openstack-nova"]
                  }
                  match_expressions {
                    key      = "app.kubernetes.io/component"
                    operator = "In"
                    values   = ["conductor"]
                  }
                }
              }
            }
          }
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -----------------------------------------------------------------------
        # Waits for required services and jobs before starting.

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
            value = "${ var.infrastructure_namespace }:rabbitmq,${ var.infrastructure_namespace }:mariadb,${ var.keystone_namespace }:keystone-api,nova-api"
          }

          env {
            name  = "DEPENDENCY_JOBS"
            value = "nova-db-sync,nova-rabbit-init"
          }

          env { 
            name = "DEPENDENCY_DAEMONSET" 
          }

          env { 
            name = "DEPENDENCY_CONTAINER" 
          }

          env { 
            name = "DEPENDENCY_POD_JSON" 
          }

          env { name = "DEPENDENCY_CUSTOM_RESOURCE" }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 65534
          }
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - NOVA CONDUCTOR
        # -----------------------------------------------------------------------
        # Runs the Nova Conductor service.

        container {
          name              = "nova-conductor"
          image             = "quay.io/airshipit/nova:2025.1-ubuntu_noble"
          image_pull_policy = "IfNotPresent"

          command = ["/tmp/nova-conductor.sh"]

          # -------------------------------------------------------------------
          # ENVIRONMENT VARIABLES
          # -------------------------------------------------------------------
          # RPC probe configuration for health monitoring.

          env {
            name  = "RPC_PROBE_TIMEOUT"
            value = "60"
          }

          env {
            name  = "RPC_PROBE_RETRIES"
            value = "2"
          }

          # -------------------------------------------------------------------
          # HEALTH PROBES
          # -------------------------------------------------------------------
          # RPC-based liveness and readiness probes for conductor service health.

          liveness_probe {
            exec {
              command = [
                "python",
                "/tmp/health-probe.py",
                "--config-file",
                "/etc/nova/nova.conf",
                "--config-dir",
                "/etc/nova/nova.conf.d",
                "--service-queue-name",
                "conductor",
                "--liveness-probe"
              ]
            }
            initial_delay_seconds = 120
            period_seconds        = 90
            timeout_seconds       = 70
            failure_threshold     = 3
            success_threshold     = 1
          }

          readiness_probe {
            exec {
              command = [
                "python",
                "/tmp/health-probe.py",
                "--config-file",
                "/etc/nova/nova.conf",
                "--config-dir",
                "/etc/nova/nova.conf.d",
                "--service-queue-name",
                "conductor"
              ]
            }
            initial_delay_seconds = 80
            period_seconds        = 90
            timeout_seconds       = 70
            failure_threshold     = 3
            success_threshold     = 1
          }

          # -------------------------------------------------------------------
          # VOLUME MOUNTS
          # -------------------------------------------------------------------
          # Configuration and runtime volumes.

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/tmp/nova-conductor.sh"
            sub_path   = "nova-conductor.sh"
            read_only  = true
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/tmp/health-probe.py"
            sub_path   = "health-probe.py"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/nova.conf"
            sub_path   = "nova.conf"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc-snippets"
            mount_path = "/etc/nova/nova.conf.d/"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/policy.yaml"
            sub_path   = "policy.yaml"
            read_only  = true
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Define required volumes for configuration and runtime.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "nova-bin"
          config_map {
            name         = "nova-bin"
            default_mode = "0555"
          }
        }

        volume {
          name = "nova-etc"
          secret {
            secret_name  = "nova-etc"
            default_mode = "0444"
          }
        }

        volume {
          name = "nova-etc-snippets"
          projected {
            default_mode = "0644"

            sources {
              secret {
                name = "nova-ks-etc"
              }
            }
          }
        }
      }
    }
  }
}