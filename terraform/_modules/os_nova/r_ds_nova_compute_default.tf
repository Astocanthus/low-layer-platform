# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# NOVA COMPUTE DAEMONSET
# =============================================================================
# This resource provisions a Kubernetes DaemonSet that runs Nova compute service
# on designated compute nodes. It manages virtual machine instances and integrates
# with libvirt, Ceph storage, and Neutron networking. The DaemonSet includes
# multiple init containers for dependency management, Ceph configuration, and
# service initialization.

# -----------------------------------------------------------------------------
# METADATA AND LABELS
# -----------------------------------------------------------------------------
# Declares the DaemonSet metadata, including standard Kubernetes labels for
# lifecycle and component tracking. These labels help with monitoring, auditing,
# and grouping.

resource "kubernetes_daemonset_v1" "nova_compute_default" {
  metadata {
    name      = "nova-compute-default"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "compute"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  # -----------------------------------------------------------------------------
  # DAEMONSET SPECIFICATION
  # -----------------------------------------------------------------------------
  # Defines the DaemonSet behavior including update strategy and pod template.

  spec {
    revision_history_limit = 10

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "nova"
        "app.kubernetes.io/instance"  = "openstack-nova"
        "app.kubernetes.io/component" = "compute"
      }
    }

    # ---------------------------------------------------------------------------
    # UPDATE STRATEGY
    # ---------------------------------------------------------------------------
    # Rolling update with no surge and max 1 pod unavailable at a time.

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 0
        max_unavailable = 1
      }
    }

    # ---------------------------------------------------------------------------
    # POD TEMPLATE SPECIFICATION
    # ---------------------------------------------------------------------------
    # This block defines the pod template that will be deployed on each node.

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "nova"
          "app.kubernetes.io/instance"  = "openstack-nova"
          "app.kubernetes.io/component" = "compute"
        }
      }

      spec {
        service_account_name             = "nova-compute"
        restart_policy                   = "Always"
        termination_grace_period_seconds = 30
        host_network                     = true
        host_pid                         = true
        host_ipc                         = true
        dns_policy                       = "ClusterFirstWithHostNet"

        # -----------------------------------------------------------------------
        # POD SECURITY CONTEXT
        # -----------------------------------------------------------------------
        # Security settings applied at the pod level.

        security_context {
          run_as_user = 42424
        }

        # -----------------------------------------------------------------------
        # POD SCHEDULING AND PLACEMENT
        # -----------------------------------------------------------------------
        # Schedules the pod on OpenStack compute nodes.

        node_selector = {
          "openstack-compute-node" = "enabled"
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER 1 - DEPENDENCY MANAGEMENT
        # -----------------------------------------------------------------------
        # Waits for required services, jobs, and pods before starting.

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
            value = "${ var.infrastructure_namespace }:rabbitmq,${ var.glance_namespace }:glance-api,nova-api,${ var.neutron_namespace }:neutron-server,nova-metadata"
          }

          env {
            name  = "DEPENDENCY_JOBS"
            value = "nova-db-sync,nova-rabbit-init"
          }

          env { 
            name = "DEPENDENCY_DAEMONSET" 
          }

          env { 
            name = "DEPENDENCY_CONTAINER" 
          }

          env {
            name  = "DEPENDENCY_POD_JSON"
            value = "[{\"labels\":{\"application\":\"libvirt\",\"component\":\"libvirt\"},\"requireSameNode\":true},{\"labels\":{\"application\":\"neutron\",\"component\":\"neutron-ovs-agent\"},\"requireSameNode\":true}]"
          }

          env { name = "DEPENDENCY_CUSTOM_RESOURCE" }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_user                = 65534
          }
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER 2 - NOVA COMPUTE INITIALIZATION
        # -----------------------------------------------------------------------
        # Prepares Nova directories and permissions.

        init_container {
          name              = "nova-compute-init"
          image             = "quay.io/airshipit/nova:2025.1-ubuntu_noble"
          image_pull_policy = "IfNotPresent"

          command = ["/tmp/nova-compute-init.sh"]

          env {
            name  = "NOVA_USER_UID"
            value = "42424"
          }

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/tmp/nova-compute-init.sh"
            sub_path   = "nova-compute-init.sh"
            read_only  = true
          }

          volume_mount {
            name       = "varlibnova"
            mount_path = "/var/lib/nova"
          }

          volume_mount {
            name       = "pod-shared"
            mount_path = "/tmp/pod-shared"
          }

          security_context {
            read_only_root_filesystem = true
            run_as_user               = 0
          }
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER 3 - CEPH PERMISSIONS
        # -----------------------------------------------------------------------
        # Sets proper ownership for Ceph configuration directory.

        init_container {
          name              = "ceph-perms"
          image             = "quay.io/airshipit/nova:2025.1-ubuntu_noble"
          image_pull_policy = "IfNotPresent"

          command = ["chown", "-R", "nova:", "/etc/ceph"]

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "etcceph"
            mount_path = "/etc/ceph"
          }

          security_context {
            read_only_root_filesystem = true
            run_as_user               = 0
          }
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER 4 - CEPH ADMIN KEYRING PLACEMENT
        # -----------------------------------------------------------------------
        # Configures Ceph admin keyring for storage access.

        init_container {
          name              = "ceph-admin-keyring-placement"
          image             = "quay.io/airshipit/nova:2025.1-ubuntu_noble"
          image_pull_policy = "IfNotPresent"

          command = ["/tmp/ceph-admin-keyring.sh"]

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "etcceph"
            mount_path = "/etc/ceph"
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/tmp/ceph-admin-keyring.sh"
            sub_path   = "ceph-admin-keyring.sh"
            read_only  = true
          }

          volume_mount {
            name       = "ceph-keyring"
            mount_path = "/tmp/client-keyring"
            sub_path   = "key"
            read_only  = true
          }
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER 5 - CEPH KEYRING PLACEMENT
        # -----------------------------------------------------------------------
        # Configures Ceph client keyring for Cinder volumes.

        init_container {
          name              = "ceph-keyring-placement"
          image             = "quay.io/airshipit/nova:2025.1-ubuntu_noble"
          image_pull_policy = "IfNotPresent"

          command = ["/tmp/ceph-keyring.sh"]

          env {
            name  = "CEPH_CINDER_USER"
            value = "cinder"
          }

          env {
            name = "LIBVIRT_CEPH_SECRET_UUID"
          }

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "etcceph"
            mount_path = "/etc/ceph"
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/tmp/ceph-keyring.sh"
            sub_path   = "ceph-keyring.sh"
          }

          volume_mount {
            name       = "ceph-etc"
            mount_path = "/etc/ceph/ceph.conf.template"
            sub_path   = "ceph.conf"
            read_only  = true
          }
        }

        # -----------------------------------------------------------------------
        # INIT CONTAINER 6 - NOVA COMPUTE VNC INITIALIZATION
        # -----------------------------------------------------------------------
        # Prepares VNC console configuration.

        init_container {
          name              = "nova-compute-vnc-init"
          image             = "quay.io/airshipit/nova:2025.1-ubuntu_noble"
          image_pull_policy = "IfNotPresent"

          command = ["/tmp/nova-console-compute-init.sh"]

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/tmp/nova-console-compute-init.sh"
            sub_path   = "nova-console-compute-init.sh"
            read_only  = true
          }

          volume_mount {
            name       = "pod-shared"
            mount_path = "/tmp/pod-shared"
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }
        }

        # -----------------------------------------------------------------------
        # MAIN CONTAINER - NOVA COMPUTE SERVICE
        # -----------------------------------------------------------------------
        # Runs the Nova compute service for managing virtual machines.

        container {
          name              = "nova-compute"
          image             = "quay.io/airshipit/nova:2025.1-ubuntu_noble"
          image_pull_policy = "IfNotPresent"

          command = ["/tmp/nova-compute.sh"]

          # -------------------------------------------------------------------
          # ENVIRONMENT VARIABLES
          # -------------------------------------------------------------------
          # Ceph and service configuration.

          env {
            name  = "CEPH_CINDER_USER"
            value = "cinder"
          }

          env {
            name = "LIBVIRT_CEPH_SECRET_UUID"
          }

          env {
            name  = "RPC_PROBE_TIMEOUT"
            value = "60"
          }

          env {
            name  = "RPC_PROBE_RETRIES"
            value = "2"
          }

          # -------------------------------------------------------------------
          # HEALTH PROBES
          # -------------------------------------------------------------------
          # Startup, liveness, and readiness probes for service health.

          startup_probe {
            exec {
              command = [
                "python",
                "/tmp/health-probe.py",
                "--config-file",
                "/etc/nova/nova.conf",
                "--config-dir",
                "/etc/nova/nova.conf.d",
                "--service-queue-name",
                "compute",
                "--liveness-probe",
                "--use-fqdn"
              ]
            }
            failure_threshold = 120
            period_seconds    = 10
            success_threshold = 1
            timeout_seconds   = 70
          }

          liveness_probe {
            exec {
              command = [
                "python",
                "/tmp/health-probe.py",
                "--config-file",
                "/etc/nova/nova.conf",
                "--config-dir",
                "/etc/nova/nova.conf.d",
                "--service-queue-name",
                "compute",
                "--liveness-probe",
                "--use-fqdn"
              ]
            }
            failure_threshold = 3
            period_seconds    = 90
            success_threshold = 1
            timeout_seconds   = 70
          }

          readiness_probe {
            exec {
              command = [
                "python",
                "/tmp/health-probe.py",
                "--config-file",
                "/etc/nova/nova.conf",
                "--config-dir",
                "/etc/nova/nova.conf.d",
                "--service-queue-name",
                "compute",
                "--use-fqdn"
              ]
            }
            failure_threshold = 3
            period_seconds    = 90
            success_threshold = 1
            timeout_seconds   = 70
          }

          # -------------------------------------------------------------------
          # VOLUME MOUNTS
          # -------------------------------------------------------------------
          # Configuration, storage, and runtime volumes.

          volume_mount {
            name       = "dev-pts"
            mount_path = "/dev/pts"
          }

          volume_mount {
            name       = "pod-tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/tmp/nova-compute.sh"
            sub_path   = "nova-compute.sh"
            read_only  = true
          }

          volume_mount {
            name       = "nova-bin"
            mount_path = "/tmp/health-probe.py"
            sub_path   = "health-probe.py"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/nova.conf"
            sub_path   = "nova-compute.conf"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc-snippets"
            mount_path = "/etc/nova/nova.conf.d/"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/logging.conf"
            sub_path   = "logging.conf"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/api-paste.ini"
            sub_path   = "api-paste.ini"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/policy.yaml"
            sub_path   = "policy.yaml"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/sudoers.d/kolla_nova_sudoers"
            sub_path   = "nova_sudoers"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/rootwrap.conf"
            sub_path   = "rootwrap.conf"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/rootwrap.d/compute.filters"
            sub_path   = "compute.filters"
            read_only  = true
          }

          volume_mount {
            name       = "nova-etc"
            mount_path = "/etc/nova/rootwrap.d/network.filters"
            sub_path   = "network.filters"
            read_only  = true
          }

          volume_mount {
            name              = "etcceph"
            mount_path        = "/etc/ceph"
            mount_propagation = "Bidirectional"
          }

          volume_mount {
            name       = "ceph-keyring"
            mount_path = "/tmp/client-keyring"
            sub_path   = "key"
            read_only  = true
          }

          volume_mount {
            name       = "libmodules"
            mount_path = "/lib/modules"
            read_only  = true
          }

          volume_mount {
            name              = "varlibnova"
            mount_path        = "/var/lib/nova"
            mount_propagation = "Bidirectional"
          }

          volume_mount {
            name              = "varliblibvirt"
            mount_path        = "/var/lib/libvirt"
            mount_propagation = "Bidirectional"
          }

          volume_mount {
            name       = "run"
            mount_path = "/run"
          }

          volume_mount {
            name       = "cgroup"
            mount_path = "/sys/fs/cgroup"
            read_only  = true
          }

          volume_mount {
            name       = "pod-shared"
            mount_path = "/tmp/pod-shared"
          }

          volume_mount {
            name       = "machine-id"
            mount_path = "/etc/machine-id"
            read_only  = true
          }

          security_context {
            privileged                 = true
            read_only_root_filesystem  = true
          }
        }

        # -----------------------------------------------------------------------
        # VOLUMES
        # -----------------------------------------------------------------------
        # Define all required volumes for configuration, storage, and runtime.

        volume {
          name = "pod-tmp"
          empty_dir {}
        }

        volume {
          name = "pod-shared"
          empty_dir {}
        }

        volume {
          name = "nova-bin"
          config_map {
            name         = "nova-bin"
            default_mode = "0555"
          }
        }

        volume {
          name = "nova-etc"
          secret {
            secret_name  = "nova-compute-default"
            default_mode = "0444"
          }
        }

        volume {
          name = "nova-etc-snippets"
          projected {
            default_mode = "0644"

            sources {
              secret {
                name = "nova-ks-etc"
              }
            }
          }
        }

        volume {
          name = "ceph-etc"
          config_map {
            name         = "ceph-etc"
            default_mode = "0444"
          }
        }

        volume {
          name = "ceph-keyring"
          secret {
            secret_name  = "pvc-ceph-client-key"
            default_mode = "0644"
          }
        }

        volume {
          name = "etcceph"
          host_path {
            path = "/var/lib/openstack-helm/compute/nova"
            type = ""
          }
        }

        volume {
          name = "dev-pts"
          host_path {
            path = "/dev/pts"
            type = ""
          }
        }

        volume {
          name = "libmodules"
          host_path {
            path = "/lib/modules"
            type = ""
          }
        }

        volume {
          name = "varlibnova"
          host_path {
            path = "/var/lib/nova"
            type = ""
          }
        }

        volume {
          name = "varliblibvirt"
          host_path {
            path = "/var/lib/libvirt"
            type = ""
          }
        }

        volume {
          name = "run"
          host_path {
            path = "/run"
            type = ""
          }
        }

        volume {
          name = "cgroup"
          host_path {
            path = "/sys/fs/cgroup"
            type = ""
          }
        }

        volume {
          name = "machine-id"
          host_path {
            path = "/etc/machine-id"
            type = ""
          }
        }
      }
    }
  }
}