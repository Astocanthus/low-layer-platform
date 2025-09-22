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
    namespace     = "kube-system"
    timeout       = 150
  }

  # Storage location mapping for different storage tiers
  storage_locations = {
    hdd = "/volume1"  # HDD-based storage volume
    ssd = "/volume2"  # SSD-based storage volume
  }

  # Common storage class parameters
  common_parameters = {
    dsm = "nas.internal"
  }
}

# -----------------------------------------------------------------------------
# CSI CREDENTIALS SECRET
# -----------------------------------------------------------------------------
# Store Synology NAS authentication credentials securely

resource "kubernetes_secret" "csi_credentials" {
  metadata {
    name      = "csi-credentials"
    namespace = local.synology_config.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "synology-csi"
    }
  }

  data = {
    username = data.vault_generic_secret.synology_credentials.data["username"]
    password = data.vault_generic_secret.synology_credentials.data["password"]
  }

  type = "Opaque"
}

# -----------------------------------------------------------------------------
# SYNOLOGY CSI DRIVER DEPLOYMENT
# -----------------------------------------------------------------------------
# Deploy the main CSI driver using Helm chart

resource "helm_release" "csi_synology" {
  name       = "synology-csi"
  repository = local.synology_config.repository
  chart      = "synology-csi"
  namespace  = local.synology_config.namespace
  version    = local.synology_config.chart_version
  timeout    = local.synology_config.timeout

  # Load CSI driver configuration from external values file
  values = [
    file("helm_values/csi_synology_config.yaml")
  ]

  # Set authentication credentials dynamically
  set {
    name  = "clientInfoSecret.clients[0].username"
    value = kubernetes_secret.csi_credentials.data.username
  }

  set {
    name  = "clientInfoSecret.clients[0].password"
    value = kubernetes_secret.csi_credentials.data.password
  }

  # Ensure proper cleanup order
  wait          = true
  wait_for_jobs = true
  cleanup_on_fail = true

  depends_on = [
    helm_release.cni_cilium,
    kubernetes_secret.csi_credentials
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
    "csi.storage.k8s.io/node-stage-secret-name"      = kubernetes_secret.csi_credentials.metadata[0].name
    "csi.storage.k8s.io/node-stage-secret-namespace" = kubernetes_secret.csi_credentials.metadata[0].namespace
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
    "csi.storage.k8s.io/node-stage-secret-name"      = kubernetes_secret.csi_credentials.metadata[0].name
    "csi.storage.k8s.io/node-stage-secret-namespace" = kubernetes_secret.csi_credentials.metadata[0].namespace
  })

  depends_on = [helm_release.csi_synology]
}