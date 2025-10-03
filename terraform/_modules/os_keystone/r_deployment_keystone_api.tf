# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE API DEPLOYMENT
# =============================================================================
# This resource provisions a Kubernetes Deployment that runs the OpenStack
# Keystone identity service API. It ensures high availability configuration,
# TLS termination, and Apache WSGI integration. To do that, it leverages an
# init container to manage dependency ordering and a main container to run
# the Keystone API service.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Defines the Deployment name, namespace, and standardized Kubernetes labels.
# These labels are used for monitoring, logging, and lifecycle management.

resource "kubernetes_deployment" "keystone_api" {
  metadata {
    name      = "keystone-api"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "api"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }

    annotations = {
      "reloader.stakater.com/auto" = "true"
    }
  }

  # -----------------------------------------------------------------------------
  # DEPLOYMENT EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Controls replica count, update strategy, and revision history.
  # The Deployment uses RollingUpdate strategy with surge and unavailability limits.

  spec {
    replicas                  = 1
    progress_deadline_seconds = 600
    revision_history_limit    = 3

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "keystone"
        "app.kubernetes.io/instance"  = "openstack-keystone"
        "app.kubernetes.io/component" = "api"
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
    # POD TEMPLATE
    # ---------------------------------------------------------------------------
    # Defines the full Pod spec, including placement, containers, volumes.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "keystone"
          "app.kubernetes.io/instance"  = "openstack-keystone"
          "app.kubernetes.io/component" = "api"
        }
      }

      spec {
        service_account_name             = "openstack-keystone-api"
        restart_policy                   = "Always"
        termination_grace_period_seconds = 30
        dns_policy                       = "ClusterFirst"

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Deployment must run on OpenStack control-plane nodes with appropriate toleration.
        # Pod anti-affinity ensures pods are spread across different hosts.

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        node_selector = {
          "openstack-control-plane" = "enabled"
        }

        security_context {
          run_as_user = 0
        }

        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 10
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/instance"
                    operator = "In"
                    values   = ["openstack-keystone"]
                  }
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["keystone"]
                  }
                  match_expressions {
                    key      = "app.kubernetes.io/component"
                    operator = "In"
                    values   = ["api"]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -----------------------------------------------------------------------
        # Ensures required services (Memcached, MariaDB) and jobs (db-sync, 
        # credential-setup, fernet-setup) are ready before main container starts.

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
            value = "${var.infrastructure_namespace}:memcached,${var.infrastructure_namespace}:mariadb"
          }

          env {
            name  = "DEPENDENCY_JOBS"
            value = "keystone-db-sync,keystone-credential-setup,keystone-fernet-setup"
          }

          env { name = "DEPENDENCY_DAEMONSET" }
          env { name = "DEPENDENCY_CONTAINER" }
          env { name = "DEPENDENCY_POD_JSON" }
          env { name = "DEPENDENCY_CUSTOM_RESOURCE" }

          resources {}

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 65534
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - KEYSTONE API
        # -----------------------------------------------------------------------
        # Executes Keystone API service inside Apache WSGI container.
        # Provides HTTP/HTTPS endpoints with health checks and graceful shutdown.

        container {
          name              = "keystone-api"
          image             = "quay.io/airshipit/keystone:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/keystone-api.sh", "start"]

          lifecycle {
            pre_stop {
              exec {
                command = ["/tmp/keystone-api.sh", "stop"]
              }
            }
          }

          port {
            name           = "api-https"
            container_port = 443
            protocol       = "TCP"
          }

          liveness_probe {
            http_get {
              path   = "/healthcheck"
              port   = 443
              scheme = "HTTPS"
            }
            initial_delay_seconds = 50
            period_seconds        = 60
            timeout_seconds       = 15
            success_threshold     = 1
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/healthcheck"
              port   = 443
              scheme = "HTTPS"
            }
            initial_delay_seconds = 15
            period_seconds        = 60
            timeout_seconds       = 15
            success_threshold     = 1
            failure_threshold     = 3
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
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
            name       = "logs-apache"
            mount_path = "/var/log/apache2"
          }

          volume_mount {
            name       = "run-apache"
            mount_path = "/var/run/apache2"
          }

          volume_mount {
            name       = "wsgi-keystone"
            mount_path = "/var/www/cgi-bin/keystone"
          }

          volume_mount {
            name       = "keystone-etc"
            mount_path = "/etc/keystone/keystone.conf"
            sub_path   = "keystone.conf"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-etc"
            mount_path = "/etc/apache2/ports.conf"
            sub_path   = "ports.conf"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-etc"
            mount_path = "/etc/keystone/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-etc"
            mount_path = "/etc/keystone/policy.yaml"
            sub_path   = "policy.yaml"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-etc"
            mount_path = "etc/keystone/access_rules.json"
            sub_path   = "access_rules.json"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-etc"
            mount_path = "etc/keystone/sso_callback_template.html"
            sub_path   = "sso_callback_template.html"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-etc"
            mount_path = "/etc/apache2/conf-enabled/wsgi-keystone.conf"
            sub_path   = "wsgi-keystone.conf"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-etc"
            mount_path = "/etc/apache2/mods-available/mpm_event.conf"
            sub_path   = "mpm_event.conf"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-etc"
            mount_path = "/etc/apache2/conf-enabled/security.conf"
            sub_path   = "security.conf"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-bin"
            mount_path = "/tmp/keystone-api.sh"
            sub_path   = "keystone-api.sh"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-fernet-keys"
            mount_path = "/etc/keystone/fernet-keys/"
          }

          volume_mount {
            name       = "keystone-credential-keys"
            mount_path = "/etc/keystone/credential-keys/"
          }

          volume_mount {
            name       = "keystone-tls-internal"
            mount_path = "/etc/ssl/keystone-tls-internal/"
          }

          volume_mount {
            name       = "keystone-tls-local"
            mount_path = "/etc/ssl/keystone-tls-local/"
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"
        }

        # -------------------------------------------------------------------------
        # VOLUMES
        # -------------------------------------------------------------------------
        # Required volumes: tmp dir, script, config dir, and configuration secrets.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "etckeystone"
          empty_dir {}
        }

        volume {
          name = "wsgi-keystone"
          empty_dir {}
        }

        volume {
          name = "logs-apache"
          empty_dir {}
        }

        volume {
          name = "run-apache"
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
            default_mode = "0565"
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

        volume {
          name = "keystone-keystone-admin"
          secret {
            secret_name  = "keystone-keystone-admin"
            default_mode = "0444"
          }
        }

        volume {
          name = "keystone-tls-internal"
          secret {
            secret_name  = "keystone-tls-internal"
            default_mode = "0644"
          }
        }

        volume {
          name = "keystone-tls-local"
          secret {
            secret_name  = "keystone-tls-local"
            default_mode = "0644"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Provides access to module-level timeout variable, used for create/update/delete ops.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}