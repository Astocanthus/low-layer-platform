# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE CREDENTIAL SETUP JOB
# =============================================================================
# This Kubernetes Job runs the Keystone credential setup procedure for OpenStack.
# It uses a helper script to generate the necessary credential keys, storing them
# in a shared volume for future usage. This is a one-time setup job that must run
# after Keystone configuration and before Keystone services are started.
# It guarantees precondition ordering with an init container that waits on
# dependencies, and includes the required runtime environment and secrets.

resource "kubernetes_job" "keystone_credential_setup" {

  # -----------------------------------------------------------------------------
  # METADATA AND LABELS
  # -----------------------------------------------------------------------------
  # Standard Kubernetes metadata used for naming, scoping, and management.
  # App labels help track application ownership, management, and grouping.

  metadata {
    name      = "keystone-credential-setup"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "credential-setup"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # This job runs once and is configured for high backoff to allow retries.
  # NonIndexed mode ensures the job runs a single pod for the task.

  spec {
    completions     = 1
    parallelism     = 1
    backoff_limit   = 1000
    completion_mode = "NonIndexed"

    # ---------------------------------------------------------------------------
    # POD TEMPLATE
    # ---------------------------------------------------------------------------
    # Defines pod-level behavior, service account, and container specifications.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "keystone"
          "app.kubernetes.io/instance"  = "openstack-keystone"
          "app.kubernetes.io/component" = "credential-setup"
        }
      }

      spec {
        service_account_name             = "openstack-keystone-credential-setup"
        restart_policy                   = "OnFailure"
        dns_policy                       = "ClusterFirst"
        termination_grace_period_seconds = 30

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Schedules the job only on OpenStack control-plane nodes.
        # Uses a toleration to run on tainted nodes.

        security_context {
          run_as_user = 42424
        }

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        node_selector = {
          "openstack-control-plane" = "enabled"
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -----------------------------------------------------------------------
        # Manages startup dependencies using kubernetes-entrypoint logic.
        # Even if no service is declared now, this maintains standard boot logic.

        init_container {
          name              = "init"
          image             = "quay.io/airshipit/kubernetes-entrypoint:latest-ubuntu_focal"
          image_pull_policy = "IfNotPresent"
          command           = ["kubernetes-entrypoint"]

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
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
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - KEYSTONE CREDENTIAL SETUP
        # -----------------------------------------------------------------------
        # Executes the fernet-manage command to initialize credentials in-place.
        # Relies on config files and environment variables injected by volumes.

        container {
          name              = "keystone-credential-setup"
          image             = "quay.io/airshipit/keystone:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["python", "/tmp/fernet-manage.py", "credential_setup"]

          env {
            name  = "KEYSTONE_USER"
            value = "keystone"
          }

          env {
            name  = "KEYSTONE_GROUP"
            value = "keystone"
          }

          env {
            name  = "KUBERNETES_NAMESPACE"
            value = var.namespace
          }

          env {
            name  = "KEYSTONE_KEYS_REPOSITORY"
            value = "/etc/keystone/credential-keys/"
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
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
            name       = "credential-keys"
            mount_path = "/etc/keystone/credential-keys/"
          }

          volume_mount {
            name       = "keystone-etc"
            mount_path = "/etc/keystone/keystone.conf"
            sub_path   = "keystone.conf"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-etc"
            mount_path = "/etc/keystone/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }

          volume_mount {
            name       = "keystone-bin"
            mount_path = "/tmp/fernet-manage.py"
            sub_path   = "fernet-manage.py"
            read_only  = true
          }
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Provides temporary and configuration files, secrets, and scripts.
        # Volumes must include Keystone config, outputs targets, and helper tools.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "etckeystone"
          empty_dir {}
        }

        volume {
          name = "credential-keys"
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
            default_mode = "0555"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Standard Terraform timeouts for lifecycle operations of this Job resource.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}