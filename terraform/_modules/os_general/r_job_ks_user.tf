# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE USER JOB RESOURCE
# =============================================================================
# This resource deploys a Kubernetes Job used to bootstrap Keystone service users
# into OpenStack using Helm charts. It runs a script (ks-user.sh) via a container
# with Heat client tools and uses credentials stored in Kubernetes Secrets to 
# authenticate against Keystone. The job is executed once with retry logic.
# The initContainer ensures all dependencies like keystone-api are available first.

resource "kubernetes_job_v1" "ks_user" {
  # -----------------------------------------------------------------------------
  # METADATA AND LABELS
  # -----------------------------------------------------------------------------
  # Provides metadata used to identify and categorize the Job in Kubernetes.
  # Includes standard labels compatible with app.kubernetes.io for observability.
  metadata {
    name      = "${each.value.module_name}-ks-user"
    namespace = each.value.namespace

    labels = {
      "app.kubernetes.io/component"  = "ks-user"
      "app.kubernetes.io/instance"   = "openstack-${each.value.module_name}"
      "app.kubernetes.io/name"       = "${each.value.module_name}"
      "app.kubernetes.io/part-of"    = "openstack"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Sets retry logic, completion policy, and parallelism.
  spec {
    backoff_limit   = 10
    completion_mode = "NonIndexed"
    completions     = 1
    parallelism     = 1

    # ---------------------------------------------------------------------------
    # POD TEMPLATE
    # ---------------------------------------------------------------------------
    # Defines the template used to spawn the Pod that executes this job.
    template {
      metadata {
        labels = {
          "app.kubernetes.io/component" = "ks-user"
          "app.kubernetes.io/instance"  = "openstack-${each.value.module_name}"
          "app.kubernetes.io/name"      = "${each.value.module_name}"
        }
      }

      spec {
        restart_policy                    = "OnFailure"
        service_account_name             = "openstack-ks-user"
        termination_grace_period_seconds = 30
        dns_policy                        = "ClusterFirst"

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Schedules job on control-plane node using toleration and selector.
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
        # Waits for the keystone-api service to be available before job execution.
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
            name = "INTERFACE_NAME" 
            value = "eth0" 
          }

          env { 
            name = "PATH" 
            value = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/" 
          }

          env {
            name  = "DEPENDENCY_SERVICE"
            value = "${var.keystone_namespace}:keystone-api"
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
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - KEYSTONE USER CREATION
        # -----------------------------------------------------------------------
        # Runs Heat client container to register the service user into Keystone.
        container {
          name              = "${each.value.module_name}-ks-user"
          image             = "quay.io/airshipit/heat:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"

          command = ["/bin/bash", "-c", "/tmp/ks-user.sh"]

          # Keystone authentication version
          env {
            name  = "OS_IDENTITY_API_VERSION"
            value = "3"
          }

          # ---------------------------------------------------------------------
          # OpenStack Global Keystone Credentials (Secret based)
          # ---------------------------------------------------------------------
          dynamic "env" {
            for_each = local.credential_keystone_env
            content {
              name = env.value
              value_from {
                secret_key_ref {
                  name = kubernetes_secret.keystone_credentials_admin[each.value.namespace].metadata[0].name
                  key  = env.value
                }
              }
            }
          }

          # ---------------------------------------------------------------------
          # Service-specific Keystone Credentials
          # ---------------------------------------------------------------------
          env {
            name  = "SERVICE_OS_SERVICE_NAME"
            value = "${each.value.module_name}"
          }

          env {
            name = "SERVICE_OS_REGION_NAME"
            value_from {
              secret_key_ref {
                name = "keystone-credentials-user"
                key  = "OS_REGION_NAME"
              }
            }
          }

          env {
            name = "SERVICE_OS_PROJECT_DOMAIN_NAME"
            value_from {
              secret_key_ref {
                name = "keystone-credentials-user"
                key  = "OS_PROJECT_DOMAIN_NAME"
              }
            }
          }

          env {
            name = "SERVICE_OS_PROJECT_NAME"
            value_from {
              secret_key_ref {
                name = "keystone-credentials-user"
                key  = "OS_PROJECT_NAME"
              }
            }
          }

          env {
            name = "SERVICE_OS_USER_DOMAIN_NAME"
            value_from {
              secret_key_ref {
                name = "keystone-credentials-user"
                key  = "OS_USER_DOMAIN_NAME"
              }
            }
          }

          env {
            name = "SERVICE_OS_USERNAME"
            value_from {
              secret_key_ref {
                name = "keystone-credentials-user"
                key  = "OS_USERNAME"
              }
            }
          }

          env {
            name = "SERVICE_OS_PASSWORD"
            value_from {
              secret_key_ref {
                name = "keystone-credentials-user"
                key  = "OS_PASSWORD"
              }
            }
          }

          env {
            name  = "SERVICE_OS_ROLES"
            value = "admin"
          }

          # ---------------------------------------------------------------------
          # VOLUME MOUNTS
          # ---------------------------------------------------------------------
          # /tmp for job script, script source from configMap, TLS secrets for Keystone
          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "ks-user-sh"
            mount_path = "/tmp/ks-user.sh"
            sub_path   = "ks-user.sh"
            read_only  = true
          }

          volume_mount {
            name       = "${each.value.module_name}-tls-local"
            mount_path = "/etc/ssl/${each.value.module_name}-tls-local/issuing_ca"
            sub_path   = "issuing_ca"
            read_only  = true
          }

          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Defines volume sources used in the container: temp storage, KS script, TLS CA
        volume {
          name      = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "ks-user-sh"
          config_map {
            name         = "general-bin"
            default_mode = "0555"
          }
        }

        volume {
          name = "${each.value.module_name}-tls-local"
          secret {
            secret_name  = "${each.value.module_name}-tls-local"
            default_mode = "0644"
          }
        }
      }
    }
  }

  # -----------------------------------------------------------------------------
  # RESOURCE TIMEOUTS
  # -----------------------------------------------------------------------------
  # Configures timeouts for lifecycle operations of the job.
  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }

  # -----------------------------------------------------------------------------
  # ITERATION CONFIGURATION
  # -----------------------------------------------------------------------------
  # This job is created for each OpenStack module defined in the inputs.
  for_each = var.openstack_modules_config
}