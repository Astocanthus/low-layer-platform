# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# CINDER BACKUP STORAGE INITIALIZATION JOB
# =============================================================================
# This resource provisions a Kubernetes Job responsible for preparing the
# persistent storage required for Cinder backup functionality. It includes
# an init container to handle dependency ordering and a main container that
# performs the actual initialization using a custom script.
# This job is intended to run once per deployment and ensures proper backup
# setup before Cinder starts operations.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Defines resource identity and categorization via labels.
# Helps track ownership, deployment group, and functional role.

resource "kubernetes_job_v1" "cinder_backup_storage_init" {
  metadata {
    name      = "cinder-backup-storage-init"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "backup-storage-init"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Controls completion behavior and retry strategy for the init job.
  # The job will retry up to 10 times before considered failed.

  spec {
    backoff_limit   = 10
    completion_mode = "NonIndexed"
    completions     = 1
    parallelism     = 1

    # ---------------------------------------------------------------------------
    # POD TEMPLATE
    # ---------------------------------------------------------------------------
    # Defines the Pod specification that executes this job.
    # Includes scheduling strategy, containers, and volume mounts.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "cinder"
          "app.kubernetes.io/instance"  = "openstack-cinder"
          "app.kubernetes.io/component" = "storage-init"
        }
      }

      spec {
        restart_policy                   = "OnFailure"
        service_account_name             = "openstack-cinder-backup-storage-init"
        termination_grace_period_seconds = 30

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Ensures the job runs on OpenStack control-plane nodes.

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

        # -----------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -----------------------------------------------------------------------
        # This init container uses kubernetes-entrypoint to block until all
        # required dependencies (services, jobs, daemonsets...) are ready.

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
            name = "DEPENDENCY_SERVICE"           
            value = "" 
          }
          
          env { 
            name = "DEPENDENCY_DAEMONSET"         
            value = "" 
          }

          env { 
            name = "DEPENDENCY_CONTAINER"         
            value = "" 
          }

          env { 
            name = "DEPENDENCY_POD_JSON"          
            value = "" 
          }

          env { 
            name = "DEPENDENCY_CUSTOM_RESOURCE"   
            value = "" 
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 65534
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"

          resources {}
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - INITIALIZE BACKUP STORAGE
        # -----------------------------------------------------------------------
        # Executes a script responsible for initializing Cinder backup storage.
        # Uses a helper image and mounts required files from config maps.

        container {
          name              = "cinder-backup-storage-init"
          image             = "docker.io/openstackhelm/ceph-config-helper:latest-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/backup-storage-init.sh"]

          env {
            name = "NAMESPACE"
            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "metadata.namespace"
              }
            }
          }

          # Example: uncomment to manually force storage backend
          # env {
          #   name  = "STORAGE_BACKEND"
          #   value = "cinder.backup.drivers.swift.SwiftBackupDriver"
          # }

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
            name       = "cinder-bin"
            mount_path = "/tmp/backup-storage-init.sh"
            sub_path   = "backup-storage-init.sh"
            read_only  = true
          }

          resources {}
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Provides temporary volume for shared data and mounts the init script
        # from a ConfigMap that contains Cinder utility binaries.

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
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Provides access to module-level timeout for create/update/delete operations.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}