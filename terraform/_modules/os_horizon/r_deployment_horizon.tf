# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# HORIZON DASHBOARD DEPLOYMENT
# =============================================================================
# This resource provisions the Horizon web dashboard for OpenStack using a
# Kubernetes Deployment. It includes init containers for dependency handling and
# a main container running the Horizon Apache WSGI service. TLS, policy files, and
# logo customization are configured via config maps and secrets, while ensuring
# appropriate scheduling and health management characteristics.

# -----------------------------------------------------------------------------
# DEPLOYMENT METADATA
# -----------------------------------------------------------------------------
# Defines deployment name, namespace, and standardized Kubernetes labels.
# These labels are used for monitoring, logging, and lifecycle management.

resource "kubernetes_deployment" "horizon" {
  metadata {
    name      = "horizon"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "horizon"
      "app.kubernetes.io/instance"   = "openstack-horizon"
      "app.kubernetes.io/component"  = "server"
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
  # Sets number of replicas and controls update behavior using rolling updates.
  # Ensures graceful deployment with history retention and deadline controls.

  spec {
    replicas                  = 1
    progress_deadline_seconds = 600
    revision_history_limit    = 3

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "horizon"
        "app.kubernetes.io/instance"  = "openstack-horizon"
        "app.kubernetes.io/component" = "server"
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
    # Describes the pod, including containers, scheduling, and placement logic.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "horizon"
          "app.kubernetes.io/instance"  = "openstack-horizon"
          "app.kubernetes.io/component" = "server"
        }
      }

      spec {
        service_account_name              = "horizon"
        termination_grace_period_seconds = 30
        dns_policy                        = "ClusterFirst"
        restart_policy                    = "Always"

        # -------------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -------------------------------------------------------------------------
        # Horizon runs on control-plane nodes only. Anti-affinity ensures pod spreading.

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
                    values   = ["openstack-horizon"]
                  }
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["horizon"]
                  }
                  match_expressions {
                    key      = "app.kubernetes.io/component"
                    operator = "In"
                    values   = ["server"]
                  }
                }
              }
            }
          }
        }

        # -------------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -------------------------------------------------------------------------
        # Waits for all services and jobs to be available before Horizon launches.
        # This ensures availability of Memcached, MariaDB and Keystone service.

        init_container {
          name              = "init"
          image             = "quay.io/airshipit/kubernetes-entrypoint:latest-ubuntu_focal"
          image_pull_policy = "IfNotPresent"
          command           = ["kubernetes-entrypoint"]

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 65534
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

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
            value = "${var.infrastructure_namespace}:memcached,${var.infrastructure_namespace}:mariadb,${var.keystone_namespace}:keystone-api"
          }

          env {
            name  = "DEPENDENCY_JOBS"
            value = "horizon-db-sync"
          }

          env { name = "DEPENDENCY_DAEMONSET" }
          env { name = "DEPENDENCY_CONTAINER" }
          env { name = "DEPENDENCY_POD_JSON" }
          env { name = "DEPENDENCY_CUSTOM_RESOURCE" }

          resources {}
        }

        # -------------------------------------------------------------------------
        # MAIN CONTAINER - HORIZON DASHBOARD
        # -------------------------------------------------------------------------
        # Renders the web interface using Apache and Django.
        # Probes defined to maintain pod health and allow graceful shutdown.

        container {
          name              = "horizon"
          image             = "quay.io/airshipit/horizon:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/horizon.sh", "start"]

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
            run_as_user                = 0
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

          env {
            name = "MY_POD_IP"
            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "status.podIP"
              }
            }
          }

          env {
            name  = "REQUESTS_CA_BUNDLE"
            value = "/etc/ssl/horizon-tls-local/issuing_ca"
          }

          port {
            container_port = 443
            name           = "web"
            protocol       = "TCP"
          }

          liveness_probe {
            http_get {
              path   = "/"
              port   = 443
              scheme = "HTTPS"
            }
            initial_delay_seconds = 180
            period_seconds        = 60
            timeout_seconds       = 5
            success_threshold     = 1
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/"
              port   = 443
              scheme = "HTTPS"
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 5
            success_threshold     = 1
            failure_threshold     = 3
          }

          lifecycle {
            pre_stop {
              exec {
                command = ["/tmp/horizon.sh", "stop"]
              }
            }
          }

          resources {}

          # ---------------------------------------------------------------------
          # VOLUME MOUNTS
          # ---------------------------------------------------------------------
          # Includes mounts for configuration, policies, scripts, WSGI app and TLS.

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "static-horizon"
            mount_path = "/var/www/html/"
          }

          volume_mount {
            name       = "horizon-bin"
            mount_path = "/tmp/horizon.sh"
            sub_path   = "horizon.sh"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-bin"
            mount_path = "/tmp/manage.py"
            sub_path   = "manage.py"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-etc"
            mount_path = "/etc/apache2/sites-available/000-default.conf"
            sub_path   = "horizon.conf"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-etc"
            mount_path = "/etc/apache2/conf-available/security.conf"
            sub_path   = "security.conf"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-bin"
            mount_path = "/var/www/cgi-bin/horizon/django.wsgi"
            sub_path   = "django.wsgi"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-etc"
            mount_path = "/etc/openstack-dashboard/local_settings"
            sub_path   = "local_settings"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-etc"
            mount_path = "/etc/openstack-dashboard/ceilometer_policy.yaml"
            sub_path   = "ceilometer_policy.yaml"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-etc"
            mount_path = "/etc/openstack-dashboard/heat_policy.yaml"
            sub_path   = "heat_policy.yaml"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-etc"
            mount_path = "/etc/openstack-dashboard/ceilometer_policy.json"
            sub_path   = "ceilometer_policy.json"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-etc"
            mount_path = "/etc/openstack-dashboard/heat_policy.json"
            sub_path   = "heat_policy.json"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-logo"
            mount_path = "/tmp/logo.svg"
            sub_path   = "miniature.svg"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-logo"
            mount_path = "/tmp/logo-splash.svg"
            sub_path   = "full.svg"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-logo"
            mount_path = "/tmp/miniature.svg"
            sub_path   = "miniature.svg"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-tls-local"
            mount_path = "/etc/ssl/horizon-tls-local/issuing_ca"
            sub_path   = "issuing_ca"
            read_only  = true
          }

          volume_mount {
            name       = "horizon-tls-internal"
            mount_path = "/etc/ssl/horizon-tls-internal"
            read_only  = true
          }
        }

        # -------------------------------------------------------------------------
        # VOLUMES
        # -------------------------------------------------------------------------
        # Definitions of volumes (tmp, bin, conf, secrets) used by containers.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "wsgi-horizon"
          empty_dir {}
        }

        volume {
          name = "static-horizon"
          empty_dir {}
        }

        volume {
          name = "horizon-bin"
          config_map {
            name         = "horizon-bin"
            default_mode = "0555"
          }
        }

        volume {
          name = "horizon-etc"
          secret {
            secret_name  = "horizon-etc"
            default_mode = "0444"
          }
        }

        volume {
          name = "horizon-logo"
          config_map {
            name         = "horizon-logo"
            default_mode = "0644"
          }
        }

        volume {
          name = "horizon-tls-local"
          secret {
            secret_name  = var.local_ca_secret_name
            default_mode = "0644"
          }
        }

        volume {
          name = "horizon-tls-internal"
          secret {
            secret_name  = "horizon-tls-internal"
            default_mode = "0644"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Leverages module-level variable for create/update/delete operations timeouts.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}