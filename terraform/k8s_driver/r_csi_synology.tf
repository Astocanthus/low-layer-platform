# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# SYNOLOGY CSI DEPLOYMENT
# =============================================================================
# Deploy Synology CSI driver with storage classes for iSCSI and SMB protocols
# Provides persistent storage integration with Synology NAS infrastructure

# -----------------------------------------------------------------------------
# SYNOLOGY CSI CONFIGURATION
# -----------------------------------------------------------------------------
# Configuration for CSI driver deployment and storage classes

locals {
  synology_config = {
    chart_version = "0.10.1"
    repository    = "https://christian-schlichtherle.github.io/synology-csi-chart"
    namespace     = "csi-synology"
    timeout       = 20
  }

  # Storage location mapping for different storage tiers
  storage_locations = {
    hdd = "/volume1"  # HDD-based storage volume
    ssd = "/volume2"  # SSD-based storage volume
  }

  csi_secret_names = {
    client_info = "synology-csi-client-info"
    smb_info    = "smb-csi-credentials"
  }

  # Common storage class parameters
  common_parameters = {
    dsm = "nas.internal"
  }
}

# -----------------------------------------------------------------------------
# CSI SYNOLOGY NAMESPACE
# -----------------------------------------------------------------------------
# Dedicated namespace for csi synology with Istio injection enabled

resource "kubernetes_namespace" "csi_synology" {
  metadata {
    name = local.synology_config.namespace
    labels = {
      "app.kubernetes.io/managed-by"               = "terraform"
      "app.kubernetes.io/component"                = "synology"
      "istio-injection"                            = "enabled"
      "pod-security.kubernetes.io/enforce"         = "privileged"
      "pod-security.kubernetes.io/enforce-version" = "latest"
    }
  }
}

# -----------------------------------------------------------------------------
# CSI CREDENTIALS SECRET
# -----------------------------------------------------------------------------
# Store Synology NAS authentication credentials securely

module "synology_csi_secret" {
  source     = "../_modules/vso_secrets"
  namespace  = kubernetes_namespace.csi_synology.metadata[0].name
  auth_mount = "kubernetes-low-layer"
  audience   = "kube.low-layer.internal"

  secrets = [{
    name    = local.csi_secret_names.client_info
    mount   = "secrets"
    path    = "backbone/synology/kubernete-low-layer"
    version = 1
    transformation = {
      excludes = [
        "username",
        "password"
      ]
      templates = {
        "client-info.yaml" = {
          text = <<EOF
            {{- printf "clients: \n" -}}
            {{- printf "- host: nas.internal \n" -}}
            {{- printf "  port: 5000 \n"  -}}
            {{- printf "  https: false \n"  -}}
            {{- printf "  username: %s \n" (get .Secrets "username") -}}
            {{- printf "  password: %s" (get .Secrets "password") -}}
          EOF
        }
      }
    }
  },
  {
    name    = local.csi_secret_names.smb_info
    mount   = "secrets"
    path    = "backbone/synology/kubernete-low-layer"
    version = 1
  }]
}

# -----------------------------------------------------------------------------
# SYNOLOGY CSI DRIVER DEPLOYMENT
# -----------------------------------------------------------------------------
# Deploy the main CSI driver using Helm chart

resource "helm_release" "csi_synology" {
  name       = "synology-csi"
  repository = local.synology_config.repository
  chart      = "synology-csi"
  namespace  = kubernetes_namespace.csi_synology.metadata[0].name
  version    = local.synology_config.chart_version
  timeout    = local.synology_config.timeout

  # Load CSI driver configuration from external values file
  values = [
    file("helm_values/csi_synology_config.yaml")
  ]

  # Ensure proper cleanup order
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true

  depends_on = [
    helm_release.cni_cilium,
    module.synology_csi_secret.kubernetes_manifest
  ]
}

# -----------------------------------------------------------------------------
# ISCSI STORAGE CLASSES
# -----------------------------------------------------------------------------
# Block storage classes using iSCSI protocol for high-performance workloads

resource "kubernetes_storage_class" "synology_iscsi_hdd" {
  metadata {
    name = "synology-iscsi-hdd"
    labels = {
      "app.kubernetes.io/managed-by"   = "terraform"
      "app.kubernetes.io/component"    = "storage-class"
      "storage.low-layer.com/tier"     = "hdd"
      "storage.low-layer.com/protocol" = "iscsi"
    }
    annotations = {
      "k10.kasten.io/sc-supports-block-mode-exports" = "true"
      "storageclass.kubernetes.io/is-default-class"  = "true"
    }
  }

  storage_provisioner    = "csi.san.synology.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  
  parameters = merge(local.common_parameters, {
    fsType   = "ext4"
    location = local.storage_locations.hdd
    protocol = "iscsi"
    type     = "thin"
  })

  depends_on = [helm_release.csi_synology]
}

resource "kubernetes_storage_class" "synology_iscsi_ssd" {
  metadata {
    name = "synology-iscsi-ssd"
    labels = {
      "app.kubernetes.io/managed-by"   = "terraform"
      "app.kubernetes.io/component"    = "storage-class"
      "storage.low-layer.com/tier"     = "ssd"
      "storage.low-layer.com/protocol" = "iscsi"
    }
    annotations = {
      "k10.kasten.io/sc-supports-block-mode-exports" = "true"
    }
  }

  storage_provisioner    = "csi.san.synology.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  
  parameters = merge(local.common_parameters, {
    fsType   = "ext4"
    location = local.storage_locations.ssd
    protocol = "iscsi"
    type     = "thin"
  })

  depends_on = [helm_release.csi_synology]
}

# -----------------------------------------------------------------------------
# SMB STORAGE CLASSES
# -----------------------------------------------------------------------------
# Network file system storage classes using SMB protocol for shared storage

resource "kubernetes_storage_class" "synology_smb_hdd" {
  metadata {
    name = "synology-smb-hdd"
    labels = {
      "app.kubernetes.io/managed-by"   = "terraform"
      "app.kubernetes.io/component"    = "storage-class"
      "storage.low-layer.com/tier"     = "hdd"
      "storage.low-layer.com/protocol" = "smb"
    }
    annotations = {
      "k10.kasten.io/sc-supports-block-mode-exports" = "true"
    }
  }

  storage_provisioner    = "csi.san.synology.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "Immediate"
  
  mount_options = [
    "dir_mode=0777",
    "file_mode=0777",
    "uid=0",
    "gid=0"
  ]
  
  parameters = merge(local.common_parameters, {
    location = local.storage_locations.hdd
    protocol = "smb"
    "csi.storage.k8s.io/node-stage-secret-name"      = local.csi_secret_names.smb_info
    "csi.storage.k8s.io/node-stage-secret-namespace" = kubernetes_namespace.csi_synology.metadata[0].name
  })

  depends_on = [helm_release.csi_synology]
}

resource "kubernetes_storage_class" "synology_smb_ssd" {
  metadata {
    name = "synology-smb-ssd"
    labels = {
      "app.kubernetes.io/managed-by"   = "terraform"
      "app.kubernetes.io/component"    = "storage-class"
      "storage.low-layer.com/tier"     = "ssd"
      "storage.low-layer.com/protocol" = "smb"
    }
    annotations = {
      "k10.kasten.io/sc-supports-block-mode-exports" = "true"
    }
  }

  storage_provisioner    = "csi.san.synology.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "Immediate"
  
  mount_options = [
    "dir_mode=0777",
    "file_mode=0777",
    "uid=0",
    "gid=0"
  ]
  
  parameters = merge(local.common_parameters, {
    location = local.storage_locations.ssd
    protocol = "smb"
    "csi.storage.k8s.io/node-stage-secret-name"      = local.csi_secret_names.smb_info
    "csi.storage.k8s.io/node-stage-secret-namespace" = kubernetes_namespace.csi_synology.metadata[0].name
  })

  depends_on = [helm_release.csi_synology]
}