# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# CINDER API DEPLOYMENT
# =============================================================================
# Deploys the OpenStack Block Storage API (Cinder) as a Kubernetes Deployment.
# The deployment includes an init container for managing inter-service dependencies
# and a main container that executes the Cinder API via Apache and WSGI.
# The deployment enforces scheduling to control-plane nodes and mounts secrets/configs
# required to securely run Cinder in an OpenStack architecture.

# -----------------------------------------------------------------------------
# DEPLOYMENT METADATA
# -----------------------------------------------------------------------------
# Defines deployment identification through metadata and standardized labels
# for monitoring, ownership, and reusable selectors by services or other resources.

resource "kubernetes_deployment" "cinder_api" {
  metadata {
    name      = "cinder-api"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "api"
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
  # Uses RollingUpdate strategy to allow zero-downtime upgrades.
  # Limits old replica retention and controls rollout concurrency.

  spec {
    replicas                  = 1
    progress_deadline_seconds = 600
    revision_history_limit    = 3

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "cinder"
        "app.kubernetes.io/instance"  = "openstack-cinder"
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
    # POD TEMPLATE SPECIFICATION
    # ---------------------------------------------------------------------------
    # Describes the pod instance which will run the Cinder API and its
    # dependencies inside the cluster.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "cinder"
          "app.kubernetes.io/instance"  = "openstack-cinder"
          "app.kubernetes.io/component" = "api"
        }
      }

      spec {
        service_account_name              = "openstack-cinder-api"
        restart_policy                    = "Always"
        termination_grace_period_seconds  = 30
        dns_policy                        = "ClusterFirst"

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND SECURITY
        # -----------------------------------------------------------------------
        # Control-plane node scheduling with workload separation via tolerations.
        # Use pod anti-affinity to avoid co-location of similar components.

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
                    values   = ["api"]
                  }
                }
              }
            }
          }
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -----------------------------------------------------------------------
        # Waits for dependent services (MariaDB, Keystone) and Kubernetes jobs
        # to complete before proceeding with API container startup.

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
            value = "${var.infrastructure_namespace}:mariadb,${var.keystone_namespace}:keystone-api"
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
        # MAIN CONTAINER - CINDER API
        # -----------------------------------------------------------------------
        # Runs the Cinder API on Apache HTTPD using WSGI. 
        # Launch and shutdown are managed via custom entry script.

        container {
          name              = "cinder-api"
          image             = "quay.io/airshipit/cinder:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/cinder-api.sh", "start"]

          port {
            name           = "cinder-api"
            container_port = 443
            protocol       = "TCP"
          }

          lifecycle {
            pre_stop {
              exec {
                command = ["/tmp/cinder-api.sh", "stop"]
              }
            }
          }

          # Optional probes can be defined to check container health
          # Enable if active readiness/liveness is desired
          #
          # liveness_probe {}
          # readiness_probe {}

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

          # ---------------------------------------------------------------------
          # VOLUME MOUNTS
          # ---------------------------------------------------------------------
          # Provides access to configs, TLS certs, and binaries required for
          # Apache and Cinder runtime configurations.

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "wsgi-cinder"
            mount_path = "/var/www/cgi-bin/cinder"
          }

          volume_mount {
            name       = "cinder-bin"
            mount_path = "/tmp/cinder-api.sh"
            sub_path   = "cinder-api.sh"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-etc"
            mount_path = "/etc/cinder/cinder-api-uwsgi.ini"
            sub_path   = "cinder-api-uwsgi.ini"
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
            name       = "cinder-etc"
            mount_path = "/etc/cinder/api_audit_map.conf"
            sub_path   = "api_audit_map.conf"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-etc"
            mount_path = "/etc/cinder/resource_filters.json"
            sub_path   = "resource_filters.json"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-etc"
            mount_path = "/etc/apache2/conf-enabled/wsgi-cinder.conf"
            sub_path   = "wsgi-cinder.conf"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-etc"
            mount_path = "/etc/apache2/mods-available/mpm_event.conf"
            sub_path   = "mpm_event.conf"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-etc"
            mount_path = "/etc/apache2/conf-enabled/security.conf"
            sub_path   = "security.conf"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-coordination"
            mount_path = "/var/lib/cinder/coordination"
          }

          volume_mount {
            name       = "cinder-groups"
            mount_path = "/var/lib/cinder/groups"
          }

          volume_mount {
            name       = "cinder-tls-internal"
            mount_path = "/etc/ssl/cinder-tls-internal/"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-tls-local"
            mount_path = "/etc/ssl/cinder-tls-local/"
            read_only  = true
          }
        }

        # ---------------------------------------------------------------------
        # VOLUMES AND STORAGE
        # ---------------------------------------------------------------------
        # Declares all volumes needed by the pod: secrets, emptyDirs,
        # config maps and TLS certificate secrets for secure communication.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "wsgi-cinder"
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
          name = "cinder-coordination"
          empty_dir {}
        }

        volume {
          name = "cinder-groups"
          empty_dir {}
        }

        volume {
          name = "cinder-tls-internal"
          secret {
            secret_name  = "cinder-tls-internal"
            default_mode = "0644"
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
  # Custom timeout configuration to prevent stuck deployments in long rollout ops.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}