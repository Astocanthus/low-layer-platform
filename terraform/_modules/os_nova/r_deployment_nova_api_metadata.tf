# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# NOVA API METADATA DEPLOYMENT
# =============================================================================
# This resource provisions a Kubernetes Deployment that runs the Nova Metadata API
# service. The metadata service provides instance metadata to virtual machines,
# enabling cloud-init and other metadata-aware applications. It includes dependency
# management and initialization containers for proper service startup.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Declares the Deployment metadata, including standard Kubernetes labels for
# lifecycle and component tracking. These labels help with monitoring, auditing,
# and grouping.

resource "kubernetes_deployment_v1" "nova_api_metadata" {
  metadata {
    name      = "nova-api-metadata"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "metadata"
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
        "app.kubernetes.io/component" = "metadata"
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
          "app.kubernetes.io/component" = "metadata"
        }

        annotations = {
          "configmap-bin-hash" = "a8f80c210bdf8f7d87afb7deb4d86c55884b2396a1ed7858649315816ebbe1b9"
          "configmap-etc-hash" = "3dc82a0e44dcb9d48520329407bf4a0529c90c7ea26b4c4949b71d4faa848799"
        }
      }

      spec {
        service_account_name             = "nova-api-metadata"
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
                    values   = ["metadata"]
                  }
                }
              }
            }
          }
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER 1 - DEPENDENCY MANAGEMENT
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
            value = "${ var.infrastructure_namespace }:rabbitmq,${ var.infrastructure_namespace }:mariadb,${ var.keystone_namespace }:keystone-api"
          }

          env {
            name  = "DEPENDENCY_JOBS"
            value = "nova-db-sync,nova-ks-user,nova-ks-endpoints,nova-rabbit-init"
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
        # INIT CONTAINER 2 - NOVA API METADATA INITIALIZATION
        # -----------------------------------------------------------------------
        # Prepares metadata API service configuration.

        init_container {
          name              = "nova-api-metadata-init"
          image             = "quay.io/airshipit/nova:2025.1-ubuntu_noble"
          image_pull_policy = "IfNotPresent"

          command = ["/tmp/nova-api-metadata-init.sh"]

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/tmp/nova-api-metadata-init.sh"
            sub_path   = "nova-api-metadata-init.sh"
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
            name       = "pod-shared"
            mount_path = "/tmp/pod-shared"
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - NOVA API METADATA
        # -----------------------------------------------------------------------
        # Runs the Nova Metadata API service.

        container {
          name              = "nova-api"
          image             = "quay.io/airshipit/nova:2025.1-ubuntu_noble"
          image_pull_policy = "IfNotPresent"

          command = [
            "/tmp/nova-api-metadata.sh",
            "start"
          ]

          # -------------------------------------------------------------------
          # CONTAINER LIFECYCLE
          # -------------------------------------------------------------------
          # PreStop hook for graceful shutdown.

          lifecycle {
            pre_stop {
              exec {
                command = [
                  "/tmp/nova-api-metadata.sh",
                  "stop"
                ]
              }
            }
          }

          # -------------------------------------------------------------------
          # CONTAINER PORTS
          # -------------------------------------------------------------------
          # Exposes metadata API port.

          port {
            container_port = 8775
            protocol       = "TCP"
          }

          # -------------------------------------------------------------------
          # HEALTH PROBES
          # -------------------------------------------------------------------
          # Liveness and readiness probes for service health.

          liveness_probe {
            http_get {
              path   = "/"
              port   = 8775
              scheme = "HTTP"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
            success_threshold     = 1
          }

          readiness_probe {
            http_get {
              path   = "/"
              port   = 8775
              scheme = "HTTP"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
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
            mount_path = "/tmp/nova-api-metadata.sh"
            sub_path   = "nova-api-metadata.sh"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/nova-metadata-uwsgi.ini"
            sub_path   = "nova-metadata-uwsgi.ini"
            read_only  = true
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/sbin/iptables"
            sub_path   = "fake-iptables.sh"
            read_only  = true
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/sbin/iptables-restore"
            sub_path   = "fake-iptables.sh"
            read_only  = true
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/sbin/iptables-save"
            sub_path   = "fake-iptables.sh"
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
            mount_path = "/etc/nova/api-paste.ini"
            sub_path   = "api-paste.ini"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/policy.yaml"
            sub_path   = "policy.yaml"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/api_audit_map.conf"
            sub_path   = "api_audit_map.conf"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/sudoers.d/kolla_nova_sudoers"
            sub_path   = "nova_sudoers"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/rootwrap.conf"
            sub_path   = "rootwrap.conf"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/rootwrap.d/api-metadata.filters"
            sub_path   = "api-metadata.filters"
            read_only  = true
          }

          volume_mount {
            name       = "pod-shared"
            mount_path = "/tmp/pod-shared"
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
          name = "pod-shared"
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