# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# GLANCE API DEPLOYMENT AND PVC
# =============================================================================
# This configuration provisions the OpenStack Glance API along with the
# PersistentVolumeClaim used for shared image storage. The deployment includes
# fault-tolerant scheduling, dependency management, TLS support, and multiple
# configuration mounts. A dedicated PVC ensures access to a shared image store
# for Glance Workers.

# -----------------------------------------------------------------------------
# PERSISTENT VOLUME CLAIM FOR GLANCE IMAGES
# -----------------------------------------------------------------------------
# Provides ReadWriteMany access to Glance image files via a Synology-backed
# StorageClass. This PVC is shared between multiple pods that require image
# access for upload or delivery.

resource "kubernetes_persistent_volume_claim_v1" "glance_images_pvc" {
  metadata {
    name      = "glance-images-pvc"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "glance"
      "app.kubernetes.io/instance"   = "openstack-glance"
      "app.kubernetes.io/component"  = "images"
      "app.kubernetes.io/part-of"    = "openstack"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    access_modes        = ["ReadWriteMany"]
    storage_class_name  = "synology-smb-hdd"

    resources {
      requests = {
        storage = "100Gi"
      }
    }
  }
}

# -----------------------------------------------------------------------------
# GLANCE API DEPLOYMENT
# -----------------------------------------------------------------------------
# This deployment runs the Glance API service with support for HA across nodes,
# shared image volume, TLS termination (via nginx-proxy), and entrypoint logic.
# It includes init containers to handle boot-time preparation and permission fix.

resource "kubernetes_deployment_v1" "glance_api" {
  metadata {
    name      = "glance-api"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "glance"
      "app.kubernetes.io/instance"   = "openstack-glance"
      "app.kubernetes.io/component"  = "api"
      "app.kubernetes.io/part-of"    = "openstack"
      "app.kubernetes.io/managed-by" = "terraform"
    }

    annotations = {
      "reloader.stakater.com/auto" = "true"
    }
  }

  # ---------------------------------------------------------------------------
  # DEPLOYMENT STRATEGY AND REPLICAS
  # ---------------------------------------------------------------------------
  # Controls rolling update behavior and sets replica count.
  # Ensures history retention for rollback and progressive rollouts.

  spec {
    replicas                   = 2
    progress_deadline_seconds  = 600
    revision_history_limit     = 3

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "glance"
        "app.kubernetes.io/instance"  = "openstack-glance"
        "app.kubernetes.io/component" = "api"
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "3"
        max_unavailable = "1"
      }
    }

    # -------------------------------------------------------------------------
    # POD TEMPLATE SPECIFICATION
    # -------------------------------------------------------------------------
    # Controls all pod-level options including init containers, service account,
    # securityContext, placement, volumes, and containers.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "glance"
          "app.kubernetes.io/instance"  = "openstack-glance"
          "app.kubernetes.io/component" = "api"
        }
      }

      spec {
        service_account_name              = "openstack-glance-api"
        restart_policy                    = "Always"
        termination_grace_period_seconds  = 30
        dns_policy                        = "ClusterFirst"

        # ---------------------------------------------------------------------
        # POD SCHEDULING: NODE SELECTORS, TOLERATIONS, AFFINITY
        # ---------------------------------------------------------------------
        # Ensures pod runs on the control-plane with spreading across nodes.

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
          fs_group    = 42424
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
                    values   = ["openstack-glance"]
                  }
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["glance"]
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

        # ---------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY ENTRYPOINT
        # ---------------------------------------------------------------------
        # Wait for dependent services and jobs (e.g. keystone, mariadb, rabbitmq)

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
            value = "${var.infrastructure_namespace}:mariadb,${var.keystone_namespace}:keystone-api,${var.infrastructure_namespace}:rabbitmq"
          }

          env {
            name  = "DEPENDENCY_JOBS"
            value = "glance-storage-init,glance-db-sync,glance-rabbit-init,glance-ks-user,glance-ks-endpoints"
          }

          # Empty variable declarations for entrypoint compatibility
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

        # ---------------------------------------------------------------------
        # INIT CONTAINER - PERMISSION FIX FOR SHARED IMAGE DIR
        # ---------------------------------------------------------------------

        init_container {
          name              = "glance-perms"
          image             = "quay.io/airshipit/glance:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command = [
            "sh", "-c", "chown -R glance:glance /var/lib/glance/images && chmod 755 /var/lib/glance/images"
          ]

          resources {}

          security_context {
            read_only_root_filesystem = true
            run_as_user               = 0
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "glance-images-shared"
            mount_path = "/var/lib/glance/images"
          }
        }

        # ---------------------------------------------------------------------
        # MAIN CONTAINER - GLANCE API
        # ---------------------------------------------------------------------

        container {
          name              = "glance-api"
          image             = "quay.io/airshipit/glance:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/glance-api.sh", "start"]

          env {
            name  = "REQUESTS_CA_BUNDLE"
            value = "/etc/ssl/glance-tls-local/issuing_ca"
          }

          lifecycle {
            pre_stop {
              exec {
                command = ["/tmp/glance-api.sh", "stop"]
              }
            }
          }

          liveness_probe {
            http_get {
              path   = "/healthcheck"
              port   = "9292"
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
            success_threshold     = 1
          }

          readiness_probe {
            http_get {
              path   = "/healthcheck"
              port   = "9292"
              scheme = "HTTP"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
            success_threshold     = 1
          }

          resources {}

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "glance-tmp"
            mount_path = "/var/lib/glance/tmp"
          }

          volume_mount {
            name       = "etcglance"
            mount_path = "/etc/glance"
          }

          volume_mount {
            name       = "glance-bin"
            mount_path = "/tmp/glance-api.sh"
            sub_path   = "glance-api.sh"
            read_only  = true
          }

          volume_mount {
            name       = "glance-etc"
            mount_path = "/etc/glance/"
          }

          volume_mount {
            name       = "glance-images-shared"
            mount_path = "/var/lib/glance/images"
          }

          volume_mount {
            name       = "glance-tls-local"
            mount_path = "/etc/ssl/glance-tls-local/issuing_ca"
            sub_path   = "issuing_ca"
            read_only  = true
          }
        }

        # ---------------------------------------------------------------------
        # SIDE CONTAINER - NGINX PROXY FOR TLS TERMINATION
        # ---------------------------------------------------------------------

        container {
          name              = "nginx-proxy"
          image             = "nginx:alpine"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "nginx-proxy"
            container_port = 8443
            protocol       = "TCP"
          }

          liveness_probe {
            http_get {
              path   = "/"
              port   = "8443"
              scheme = "HTTPS"
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
              port   = "8443"
              scheme = "HTTPS"
            }
            period_seconds    = 10
            timeout_seconds   = 5
            failure_threshold = 3
            success_threshold = 1
          }

          resources {}

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "glance-etc"
            mount_path = "/etc/nginx/nginx.conf"
            sub_path   = "nginx.conf"
            read_only  = true
          }

          volume_mount {
            name       = "glance-tls-internal"
            mount_path = "/etc/ssl/glance-tls-internal/"
            read_only  = true
          }

          volume_mount {
            name       = "glance-tls-local"
            mount_path = "/etc/ssl/glance-tls-local/"
            read_only  = true
          }
        }

        # ---------------------------------------------------------------------
        # POD VOLUME DEFINITIONS
        # ---------------------------------------------------------------------
        # Required shared mounts, secrets, configMaps, and scratch volumes

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "glance-tmp"
          empty_dir {}
        }

        volume {
          name = "etcglance"
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
          name = "glance-etc"
          secret {
            secret_name  = "glance-etc"
            default_mode = "0444"
          }
        }

        volume {
          name = "glance-images-shared"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.glance_images_pvc.metadata[0].name
          }
        }

        volume {
          name = "glance-tls-internal"
          secret {
            secret_name  = "glance-tls-internal"
            default_mode = "0644"
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

  # -----------------------------------------------------------------------------
  # RESOURCE DEPENDENCY MANAGEMENT
  # -----------------------------------------------------------------------------
  # Ensures the Glance API pods wait for image PVC provisioning before startup
  
  depends_on = [
    kubernetes_persistent_volume_claim_v1.glance_images_pvc
  ]

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Allows tuning creation/deletion timeouts for long startup scenarios

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}