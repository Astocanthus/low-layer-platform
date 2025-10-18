# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# resource "kubernetes_job" "cinder_storage_init" {
#   metadata {
#     name      = "cinder-storage-init"
#     namespace = "openstack-cinder"
    
#     labels = {
#       "app.kubernetes.io/component" = "storage-init"
#       "app.kubernetes.io/instance"  = "openstack-cinder"
#       "app.kubernetes.io/name"      = "cinder"
#     }
#   }

#   spec {
#     backoff_limit   = 10
#     completion_mode = "NonIndexed"
#     completions     = 1
#     parallelism     = 1
    
#     template {
#       metadata {
#         labels = {
#           "app.kubernetes.io/component" = "storage-init"
#           "app.kubernetes.io/instance"  = "openstack-cinder"
#           "app.kubernetes.io/name"      = "cinder"
#         }
#       }
      
#       spec {
#         restart_policy                   = "OnFailure"
#         service_account_name             = "cinder-storage-init"
#         termination_grace_period_seconds = 30

        # toleration {
        #   key      = "node-role.kubernetes.io/control-plane"
        #   operator = "Exists"
        #   effect   = "NoSchedule"
        # }
        
#         node_selector = {
#           "openstack-control-plane" = "enabled"
#         }

#         # Init containers
#         init_container {
#           name  = "init"
#           image = "quay.io/airshipit/kubernetes-entrypoint:latest-ubuntu_focal"
#           image_pull_policy = "IfNotPresent"
          
#           command = ["kubernetes-entrypoint"]
          
#           env {
#             name = "POD_NAME"
#             value_from {
#               field_ref {
#                 api_version = "v1"
#                 field_path  = "metadata.name"
#               }
#             }
#           }
          
#           env {
#             name = "NAMESPACE"
#             value_from {
#               field_ref {
#                 api_version = "v1"
#                 field_path  = "metadata.namespace"
#               }
#             }
#           }
          
#           env {
#             name  = "INTERFACE_NAME"
#             value = "eth0"
#           }
          
#           env {
#             name  = "PATH"
#             value = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/"
#           }
          
#           env {
#             name = "DEPENDENCY_SERVICE"
#           }
          
#           env {
#             name = "DEPENDENCY_DAEMONSET"
#           }
          
#           env {
#             name = "DEPENDENCY_CONTAINER"
#           }
          
#           env {
#             name = "DEPENDENCY_POD_JSON"
#           }
          
#           env {
#             name = "DEPENDENCY_CUSTOM_RESOURCE"
#           }
          
#           security_context {
#             allow_privilege_escalation = false
#             read_only_root_filesystem  = true
#             run_as_user               = 65534
#           }
          
#           termination_message_path   = "/dev/termination-log"
#           termination_message_policy = "File"
#         }

#         init_container {
#           name  = "ceph-keyring-placement"
#           image = "docker.io/openstackhelm/ceph-config-helper:latest-ubuntu_jammy"
#           image_pull_policy = "IfNotPresent"
          
#           command = ["/tmp/ceph-admin-keyring.sh"]
          
#           security_context {
#             run_as_user = 0
#           }
          
#           volume_mount {
#             name       = "pod-tmp"
#             mount_path = "/tmp"
#           }
          
#           volume_mount {
#             name       = "etcceph"
#             mount_path = "/etc/ceph"
#           }
          
#           volume_mount {
#             name       = "cinder-bin"
#             mount_path = "/tmp/ceph-admin-keyring.sh"
#             sub_path   = "ceph-admin-keyring.sh"
#             read_only  = true
#           }
          
#           volume_mount {
#             name       = "ceph-keyring"
#             mount_path = "/tmp/client-keyring"
#             sub_path   = "key"
#             read_only  = true
#           }
          
#           termination_message_path   = "/dev/termination-log"
#           termination_message_policy = "File"
#         }

#         # Main container
#         container {
#           name  = "cinder-storage-init-rbd1"
#           image = "docker.io/openstackhelm/ceph-config-helper:latest-ubuntu_jammy"
#           image_pull_policy = "IfNotPresent"
          
#           command = ["/tmp/storage-init.sh"]
          
#           env {
#             name = "NAMESPACE"
#             value_from {
#               field_ref {
#                 api_version = "v1"
#                 field_path  = "metadata.namespace"
#               }
#             }
#           }
          
#           env {
#             name  = "STORAGE_BACKEND"
#             value = "cinder.volume.drivers.rbd.RBDDriver"
#           }
          
#           env {
#             name  = "RBD_POOL_NAME"
#             value = "cinder.volumes"
#           }
          
#           env {
#             name  = "RBD_POOL_APP_NAME"
#             value = "cinder-volume"
#           }
          
#           env {
#             name  = "RBD_POOL_USER"
#             value = "cinder"
#           }
          
#           env {
#             name  = "RBD_POOL_CRUSH_RULE"
#             value = "replicated_rule"
#           }
          
#           env {
#             name  = "RBD_POOL_REPLICATION"
#             value = "3"
#           }
          
#           env {
#             name  = "RBD_POOL_CHUNK_SIZE"
#             value = "8"
#           }
          
#           env {
#             name  = "RBD_POOL_SECRET"
#             value = "cinder-volume-rbd-keyring"
#           }
          
#           volume_mount {
#             name       = "pod-tmp"
#             mount_path = "/tmp"
#           }
          
#           volume_mount {
#             name       = "cinder-bin"
#             mount_path = "/tmp/storage-init.sh"
#             sub_path   = "storage-init.sh"
#             read_only  = true
#           }
          
#           volume_mount {
#             name       = "etcceph"
#             mount_path = "/etc/ceph"
#           }
          
#           volume_mount {
#             name       = "ceph-etc"
#             mount_path = "/etc/ceph/ceph.conf"
#             sub_path   = "ceph.conf"
#             read_only  = true
#           }
          
#           volume_mount {
#             name       = "ceph-keyring"
#             mount_path = "/tmp/client-keyring"
#             sub_path   = "key"
#             read_only  = true
#           }
          
#           termination_message_path   = "/dev/termination-log"
#           termination_message_policy = "File"
#         }

#         # Volumes
#         volume {
#           name = "pod-tmp"
#           empty_dir {}
#         }
        
#         volume {
#           name = "cinder-bin"
#           config_map {
#             name         = "cinder-bin"
#             default_mode = "0555"  # 365 en octal = 0555
#           }
#         }
        
#         volume {
#           name = "etcceph"
#           empty_dir {}
#         }
        
#         volume {
#           name = "ceph-etc"
#           config_map {
#             name         = "ceph-etc"
#             default_mode = "0444"  # 292 en octal = 0444
#           }
#         }
        
#         volume {
#           name = "ceph-keyring"
#           secret {
#             secret_name  = "pvc-ceph-client-key"
#             default_mode = "0644"  # 420 en octal = 0644
#           }
#         }
#       }
#     }
#   }
# }
