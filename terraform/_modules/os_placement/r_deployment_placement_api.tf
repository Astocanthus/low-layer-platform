resource "kubernetes_deployment_v1" "placement_api" {
  metadata {
    name      = "placement-api"
    namespace = var.namespace
    
    labels = {
      "app.kubernetes.io/component"  = "api"
      "app.kubernetes.io/instance"   = "openstack-placement"
      "app.kubernetes.io/name"       = "placement"
    }

    annotations = {
      "openstackhelm.openstack.org/release_uuid" = ""
    }
  }
  
  spec {
    replicas                   = 1
    progress_deadline_seconds  = 600
    revision_history_limit     = 3
    
    selector {
      match_labels = {
        "app.kubernetes.io/component" = "api"
        "app.kubernetes.io/instance"  = "openstack-placement"
        "app.kubernetes.io/name"      = "placement"
      }
    }
    
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "3"
        max_unavailable = "1"
      }
    }
    
    template {
      metadata {
        labels = {
          "app.kubernetes.io/component" = "api"
          "app.kubernetes.io/instance"  = "openstack-placement"
          "app.kubernetes.io/name"      = "placement"
        }
        
        annotations = {
          "configmap-bin-hash"                       = ""
          "configmap-etc-hash"                       = ""
          "openstackhelm.openstack.org/release_uuid" = ""
        }
      }
      
      spec {
        service_account_name              = "openstack-placement-api"
        restart_policy                    = "Always"
        termination_grace_period_seconds  = 30
        dns_policy                        = "ClusterFirst"
        
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
        
        # Affinity rules pour éviter la co-localisation
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 10
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/instance"
                    operator = "In"
                    values   = ["openstack-placement"]
                  }
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["placement"]
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
        
        # Init Container - kubernetes-entrypoint
        init_container {
          name              = "init"
          image             = "quay.io/airshipit/kubernetes-entrypoint:latest-ubuntu_focal"
          image_pull_policy = "IfNotPresent"
          
          command = ["kubernetes-entrypoint"]
          
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
            value = ""
          }
          
          env {
            name  = "DEPENDENCY_JOBS"
            value = "placement-db-sync,placement-ks-service,placement-ks-user,placement-ks-endpoints"
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
          
          env {
            name = "DEPENDENCY_CUSTOM_RESOURCE"
          }
          
          resources {}
          
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user               = 65534
          }
          
          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"
        }
        
        # Container principal - placement-api
        container {
          name              = "placement-api"
          image             = "quay.io/airshipit/placement:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          
          command = ["/tmp/placement-api.sh", "start"]
          
          port {
            container_port = 443
            name          = "placement-api"
            protocol      = "TCP"
          }
          
          # Probes de santé
        #   liveness_probe {
        #     http_get {
        #       path   = "/"
        #       port   = "443"
        #       scheme = "HTTPS"
        #     }
        #     initial_delay_seconds = 5
        #     period_seconds        = 10
        #     timeout_seconds       = 1
        #     failure_threshold     = 3
        #     success_threshold     = 1
        #   }
          
        #   readiness_probe {
        #     http_get {
        #       path   = "/"
        #       port   = "443"
        #       scheme = "HTTPS"
        #     }
        #     initial_delay_seconds = 5
        #     period_seconds        = 10
        #     timeout_seconds       = 1
        #     failure_threshold     = 3
        #     success_threshold     = 1
        #   }
          
          # Lifecycle hook
          lifecycle {
            pre_stop {
              exec {
                command = ["/tmp/placement-api.sh", "stop"]
              }
            }
          }
          
          resources {}
          
          security_context {
            read_only_root_filesystem = false
            run_as_user              = 0
          }
          
          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"
          
          # Volume mounts
          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }
          
          volume_mount {
            name       = "wsgi-placement"
            mount_path = "/var/www/cgi-bin/placement"
          }
          
          volume_mount {
            name       = "placement-bin"
            mount_path = "/tmp/placement-api.sh"
            sub_path   = "placement-api.sh"
            read_only  = true
          }
          
          volume_mount {
            name       = "placement-etc"
            mount_path = "/etc/placement/placement.conf"
            sub_path   = "placement.conf"
            read_only  = true
          }
          
          volume_mount {
            name       = "placement-etc"
            mount_path = "/etc/placement/placement-api-uwsgi.ini"
            sub_path   = "placement-api-uwsgi.ini"
            read_only  = true
          }
          
          volume_mount {
            name       = "placement-etc"
            mount_path = "/etc/placement/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }
          
          volume_mount {
            name       = "placement-etc"
            mount_path = "/etc/placement/policy.yaml"
            sub_path   = "policy.yaml"
            read_only  = true
          }
          
          volume_mount {
            name       = "placement-etc"
            mount_path = "/etc/apache2/conf-enabled/wsgi-placement.conf"
            sub_path   = "wsgi-placement.conf"
            read_only  = true
          }

          volume_mount {
            name       = "placement-tls-internal"
            mount_path = "/etc/ssl/placement-tls-internal/"
            read_only  = true
          }

          volume_mount {
            name       = "placement-tls-local"
            mount_path = "/etc/ssl/placement-tls-local/"
            read_only  = true
          }
        }
        
        # Volumes
        volume {
          name = "pod-tmp"
          empty_dir {}
        }
        
        volume {
          name = "wsgi-placement"
          empty_dir {}
        }
        
        volume {
          name = "placement-bin"
          config_map {
            name         = "placement-bin"
            default_mode = "0555"
          }
        }
        
        volume {
          name = "placement-etc"
          secret {
            secret_name  = "placement-etc"
            default_mode = "0444"
          }
        }

        volume {
          name = "placement-tls-internal"
          secret {
            secret_name  = "placement-tls-internal"
            default_mode = "0644"
          }
        }

        volume {
          name = "placement-tls-local"
          secret {
            secret_name  = "placement-tls-local"
            default_mode = "0644"
          }
        }
      }
    }
  }

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}