# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# NOVA NOVNC PROXY DEPLOYMENT
# =============================================================================
# This resource provisions a Kubernetes Deployment that runs the Nova noVNC
# proxy service. The noVNC proxy provides browser-based VNC console access to
# virtual machine instances. It includes asset initialization for the noVNC
# web client and uses host networking for direct console connectivity.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Declares the Deployment metadata, including standard Kubernetes labels for
# lifecycle and component tracking. These labels help with monitoring, auditing,
# and grouping.

resource "kubernetes_deployment_v1" "nova_novncproxy" {
  metadata {
    name      = "nova-novncproxy"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "novnc-proxy"
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
        "app.kubernetes.io/component" = "novnc-proxy"
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
          "app.kubernetes.io/component" = "novnc-proxy"
        }
      }

      spec {
        service_account_name             = "nova-novncproxy"
        restart_policy                   = "Always"
        termination_grace_period_seconds = 30
        host_network                     = true
        dns_policy                       = "ClusterFirstWithHostNet"

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
                    values   = ["novnc-proxy"]
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
            value = "${ var.infrastructure_namespace }:mariadb"
          }

          env {
            name  = "DEPENDENCY_JOBS"
            value = "nova-db-sync"
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
        # INIT CONTAINER 2 - NOVA NOVNCPROXY INITIALIZATION
        # -----------------------------------------------------------------------
        # Prepares noVNC proxy service configuration.

        init_container {
          name              = "nova-novncproxy-init"
          image             = "quay.io/airshipit/nova:2025.1-ubuntu_noble"
          image_pull_policy = "IfNotPresent"

          command = ["/tmp/nova-console-proxy-init.sh"]

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/tmp/nova-console-proxy-init.sh"
            sub_path   = "nova-console-proxy-init.sh"
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
            mount_path = "/etc/nova/nova.conf.d"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/logging.conf"
            sub_path   = "logging.conf"
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
        # INIT CONTAINER 3 - NOVNC ASSETS INITIALIZATION
        # -----------------------------------------------------------------------
        # Copies noVNC web client assets to shared volume.

        init_container {
          name              = "nova-novncproxy-init-assets"
          image             = "docker.io/kolla/ubuntu-source-nova-novncproxy:wallaby"
          image_pull_policy = "IfNotPresent"

          command = ["/tmp/nova-console-proxy-init-assets.sh"]

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/tmp/nova-console-proxy-init-assets.sh"
            sub_path   = "nova-console-proxy-init-assets.sh"
            read_only  = true
          }

          volume_mount {
            name       = "pod-usr-share-novnc"
            mount_path = "/tmp/usr/share/novnc"
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - NOVA NOVNC PROXY
        # -----------------------------------------------------------------------
        # Runs the Nova noVNC proxy service.

        container {
          name              = "nova-novncproxy"
          image             = "quay.io/airshipit/nova:2025.1-ubuntu_noble"
          image_pull_policy = "IfNotPresent"

          command = ["/tmp/nova-console-proxy.sh"]

          # -------------------------------------------------------------------
          # CONTAINER PORTS
          # -------------------------------------------------------------------
          # Exposes noVNC proxy port.

          port {
            name           = "n-novnc"
            container_port = 6080
            protocol       = "TCP"
          }

          # -------------------------------------------------------------------
          # HEALTH PROBES
          # -------------------------------------------------------------------
          # TCP socket-based liveness and readiness probes.

          liveness_probe {
            tcp_socket {
              port = 6080
            }
            initial_delay_seconds = 30
            period_seconds        = 60
            timeout_seconds       = 15
            failure_threshold     = 3
            success_threshold     = 1
          }

          readiness_probe {
            tcp_socket {
              port = 6080
            }
            initial_delay_seconds = 30
            period_seconds        = 60
            timeout_seconds       = 15
            failure_threshold     = 3
            success_threshold     = 1
          }

          # -------------------------------------------------------------------
          # VOLUME MOUNTS
          # -------------------------------------------------------------------
          # Configuration, runtime, and noVNC assets volumes.

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/tmp/nova-console-proxy.sh"
            sub_path   = "nova-console-proxy.sh"
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
            mount_path = "/etc/nova/nova.conf.d"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }

          volume_mount {
            name       = "pod-usr-share-novnc"
            mount_path = "/usr/share/novnc"
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
        # VOLUMES
        # -----------------------------------------------------------------------
        # Define required volumes for configuration, runtime, and noVNC assets.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "pod-shared"
          empty_dir {}
        }

        volume {
          name = "pod-usr-share-novnc"
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