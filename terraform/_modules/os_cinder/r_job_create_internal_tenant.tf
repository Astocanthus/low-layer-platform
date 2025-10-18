# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# CINDER INTERNAL TENANT CREATION JOB
# =============================================================================
# This resource defines a Kubernetes Job that creates an internal OpenStack
# tenant for the Cinder service. It ensures that identity configuration
# for internal Cinder users is provisioned before service startup.
# The job uses an init container to enforce dependency readiness before running
# the setup script in the main container.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Provides standardized labeling and naming for observability and integration.
# Labels help categorize the job under its purpose and ownership.

resource "kubernetes_job" "cinder_create_internal_tenant" {
  metadata {
    name      = "cinder-create-internal-tenant"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "create-internal-tenant"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Controls execution behavior including retries, parallelism, and completion.
  # Runs only once with retry on failure.

  spec {
    backoff_limit   = 10
    completion_mode = "NonIndexed"
    completions     = 1
    parallelism     = 1

    # -----------------------------------------------------------------------------
    # POD TEMPLATE
    # -----------------------------------------------------------------------------
    # Defines the Pod specification for the Job including containers, scheduling,
    # security context, volumes, and restart behavior.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "cinder"
          "app.kubernetes.io/instance"  = "openstack-cinder"
          "app.kubernetes.io/component" = "create-internal-tenant"
        }
      }

      spec {
        service_account_name              = "openstack-cinder-create-internal-tenant"
        restart_policy                    = "OnFailure"
        termination_grace_period_seconds = 30

        # -------------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -------------------------------------------------------------------------
        # Ensures this job is scheduled only on OpenStack control-plane nodes.

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

        # -------------------------------------------------------------------------
        # INIT CONTAINER - DEPENDENCY MANAGEMENT
        # -------------------------------------------------------------------------
        # Enforces dependency readiness before running main container.
        # Waits for Keystone API service to become ready.

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
            value = "${var.keystone_namespace}:keystone-api"
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

          resources {}
        }

        # -------------------------------------------------------------------------
        # MAIN CONTAINER - TENANT CREATION SCRIPT
        # -------------------------------------------------------------------------
        # Runs the tenant creation script using Heat client configured
        # with Keystone service credentials.

        container {
          name              = "create-internal-tenant"
          image             = "quay.io/airshipit/heat:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/tmp/create-internal-tenant.sh"]

          # Dynamic environment variables from Keystone admin credentials
          dynamic "env" {
            for_each = local.credential_keystone_env
            content {
              name = env.value
              value_from {
                secret_key_ref {
                  name = data.kubernetes_secret.keystone_credentials_admin.metadata[0].name
                  key  = env.value
                }
              }
            }
          }

          # Static secret-based service credentials
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

          # Static values needed at runtime
          env {
            name  = "OS_IDENTITY_API_VERSION"
            value = "3"
          }

          env {
            name  = "SERVICE_OS_SERVICE_NAME"
            value = "cinder"
          }

          env {
            name  = "INTERNAL_PROJECT_NAME"
            value = "internal_cinder"
          }

          env {
            name  = "INTERNAL_USER_NAME"
            value = "internal_cinder"
          }

          env {
            name  = "SERVICE_OS_ROLES"
            value = "admin,service"
          }

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
            name       = "create-internal-tenant-sh"
            mount_path = "/tmp/create-internal-tenant.sh"
            sub_path   = "create-internal-tenant.sh"
            read_only  = true
          }

          volume_mount {
            name       = "cinder-tls-local"
            mount_path = "/etc/ssl/cinder-tls-local/issuing_ca"
            sub_path   = "issuing_ca"
            read_only  = true
          }

          resources {}
        }

        # -------------------------------------------------------------------------
        # VOLUMES
        # -------------------------------------------------------------------------
        # Volumes for script execution, temporary directory, and TLS secrets.
        # Provide binary script files and service-side certificates.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "create-internal-tenant-sh"
          config_map {
            name         = "cinder-bin"
            default_mode = "0555"
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
  # Defines the maximum duration for create, update, and delete operations.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }
}