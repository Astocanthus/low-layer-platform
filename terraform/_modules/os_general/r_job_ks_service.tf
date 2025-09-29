# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE SERVICE REGISTRATION JOB
# =============================================================================
# This resource deploys a Kubernetes Job responsible for registering an
# OpenStack service into Keystone. It ensures that the Keystone catalog
# is correctly configured with the appropriate service type and endpoints.
# The job runs once at initialization and is designed to be idempotent.

resource "kubernetes_job_v1" "ks_service" {

  # -----------------------------------------------------------------------------
  # METADATA AND LABELS
  # -----------------------------------------------------------------------------
  # Defines unique job name and applies common labels for identification
  # and automation within the cluster.

  metadata {
    name      = "${each.value.module_name}-ks-service"
    namespace = each.value.namespace

    labels = {
      "app.kubernetes.io/name"       = "${each.value.module_name}"
      "app.kubernetes.io/component"  = "ks-service"
      "app.kubernetes.io/instance"   = "openstack-${each.value.module_name}"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # JOB EXECUTION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Sets limits on retries and parallelism. Ensures the job runs once and
  # retries up to 10 times in case of failure.

  spec {
    backoff_limit   = 10
    completion_mode = "NonIndexed"
    completions     = 1
    parallelism     = 1

    # ---------------------------------------------------------------------------
    # POD TEMPLATE
    # ---------------------------------------------------------------------------
    # Template for the pod created by the job, containing one init container
    # and one main container. Also defines security, redundancy, and node scheduling.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"       = "${each.value.module_name}"
          "app.kubernetes.io/component"  = "ks-service"
          "app.kubernetes.io/instance"   = "openstack-${each.value.module_name}"
          "app.kubernetes.io/managed-by" = "terraform"
          "app.kubernetes.io/part-of"    = "openstack"
        }
      }

      spec {
        restart_policy                     = "OnFailure"
        termination_grace_period_seconds  = 30
        service_account_name              = "openstack-ks-service"

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Targets control plane nodes where control-plane specific daemons run.

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
        # Uses kubernetes-entrypoint to manage service dependencies and delay
        # execution until Keystone service is reachable.

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

          env {
            name  = "DEPENDENCY_DAEMONSET"
            value = ""
          }

          env {
            name  = "DEPENDENCY_CONTAINER"
            value = ""
          }

          env {
            name  = "DEPENDENCY_POD_JSON"
            value = ""
          }

          env {
            name  = "DEPENDENCY_CUSTOM_RESOURCE"
            value = ""
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 65534
          }

          resources {}
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - KEYSTONE SERVICE REGISTRATION
        # -----------------------------------------------------------------------
        # Runs the ks-service.sh script which registers the given module name
        # as a service in Keystone with the provided service type. Sensitive
        # credentials are injected as secrets.

        container {
          name              = "image-ks-service-registration"
          image             = "quay.io/airshipit/heat:2024.1-ubuntu_jammy"
          image_pull_policy = "IfNotPresent"
          command           = ["/bin/bash", "-c", "/tmp/ks-service.sh"]

          env {
            name  = "OS_IDENTITY_API_VERSION"
            value = "3"
          }

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

          env {
            name  = "OS_SERVICE_NAME"
            value = "${each.value.module_name}"
          }

          env {
            name  = "OS_SERVICE_TYPE"
            value = "${each.value.service_type}"
          }

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "ks-service-sh"
            mount_path = "/tmp/ks-service.sh"
            sub_path   = "ks-service.sh"
            read_only  = true
          }

          volume_mount {
            name       = "${each.value.module_name}-tls-local"
            mount_path = "/etc/ssl/${each.value.module_name}-tls-local/issuing_ca"
            sub_path   = "issuing_ca"
            read_only  = true
          }

          resources {}
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Defines volumes needed for execution: temp dir, script config, and TLS secrets

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "ks-service-sh"
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
  # Configures timeouts for create/update/delete operations of the job.

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }

  # -----------------------------------------------------------------------------
  # ITERATION CONFIGURATION
  # -----------------------------------------------------------------------------
  # Applies this job configuration to each module defined in the input variable.

  for_each = var.openstack_modules_config
}