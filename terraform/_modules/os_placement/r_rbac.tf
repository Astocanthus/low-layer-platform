# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# PLACEMENT SERVICE ACCOUNT AND ROLE-BASED ACCESS CONTROL (RBAC)
# =============================================================================
# This file provisions the required ServiceAccounts and RBAC rules for
# the Placement service. It defines namespace-scoped roles and bindings,
# enabling controlled access to Kubernetes resources needed by Placement
# workloads.

# -----------------------------------------------------------------------------
# SERVICE ACCOUNT DEFINITIONS
# -----------------------------------------------------------------------------
# Declares a list of ServiceAccounts used by Placement components within
# the application namespace.

resource "kubernetes_service_account" "placement" {
  for_each = { for sa_name in local.service_accounts : sa_name => sa_name }

  metadata {
    name      = each.value
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "placement"
      "app.kubernetes.io/instance"   = "openstack-placement"
      "app.kubernetes.io/component"  = "resource-tracking"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }
}

# -----------------------------------------------------------------------------
# ROLE DEFINITIONS (NAMESPACE-SCOPED)
# -----------------------------------------------------------------------------
# Provides access to Kubernetes resources required by Placement
# inside the main application namespace.

resource "kubernetes_role" "placement" {
  for_each = local.role

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "placement"
      "app.kubernetes.io/instance"   = "openstack-placement"
      "app.kubernetes.io/component"  = "resource-tracking"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  rule {
    api_groups = each.value.api_groups
    resources  = each.value.resources
    verbs      = each.value.verbs
  }
}

# -----------------------------------------------------------------------------
# ROLE BINDINGS (APPLICATION NAMESPACE)
# -----------------------------------------------------------------------------
# Binds the namespace-scoped roles to the defined Placement ServiceAccounts.

resource "kubernetes_role_binding" "placement" {
  for_each = local.role_bindings

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "placement"
      "app.kubernetes.io/instance"   = "openstack-placement"
      "app.kubernetes.io/component"  = "resource-tracking"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = each.key
  }

  dynamic "subject" {
    for_each = each.value
    content {
      kind      = "ServiceAccount"
      name      = subject.value
      namespace = var.namespace
    }
  }
}

# -----------------------------------------------------------------------------
# INFRASTRUCTURE RBAC (DISABLED)
# -----------------------------------------------------------------------------
# Defines optional roles and bindings scoped to the infrastructure namespace.
# Uncomment for Placement components that need cross-namespace access.

# resource "kubernetes_role" "placement_infrastructure" {
#   for_each = local.role_infrastructure
#
#   metadata {
#     name      = each.key
#     namespace = var.infrastructure_namespace
#
#     labels = {
#       "app.kubernetes.io/name"       = "placement"
#       "app.kubernetes.io/instance"   = "openstack-placement"
#       "app.kubernetes.io/component"  = "resource-tracking"
#       "app.kubernetes.io/managed-by" = "terraform"
#       "app.kubernetes.io/part-of"    = "openstack"
#     }
#   }
#
#   rule {
#     api_groups = each.value.api_groups
#     resources  = each.value.resources
#     verbs      = each.value.verbs
#   }
# }

# resource "kubernetes_role_binding" "placement_infrastructure" {
#   for_each = local.role_binding_infrastructure
#
#   metadata {
#     name      = each.key
#     namespace = var.infrastructure_namespace
#
#     labels = {
#       "app.kubernetes.io/name"       = "placement"
#       "app.kubernetes.io/instance"   = "openstack-placement"
#       "app.kubernetes.io/component"  = "resource-tracking"
#       "app.kubernetes.io/managed-by" = "terraform"
#       "app.kubernetes.io/part-of"    = "openstack"
#     }
#   }
#
#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "Role"
#     name      = each.key
#   }
#
#   dynamic "subject" {
#     for_each = each.value
#     content {
#       kind      = "ServiceAccount"
#       name      = subject.value
#       namespace = var.namespace
#     }
#   }
# }

# -----------------------------------------------------------------------------
# KEYSTONE INTEGRATION RBAC (DISABLED)
# -----------------------------------------------------------------------------
# Provides optional cross-namespace RBAC rules for Keystone interaction.
# Uncomment if Placement requires access to Keystone resources.

# resource "kubernetes_role" "placement_keystone" {
#   for_each = local.role_keystone
#
#   metadata {
#     name      = each.key
#     namespace = var.keystone_namespace
#
#     labels = {
#       "app.kubernetes.io/name"       = "placement"
#       "app.kubernetes.io/instance"   = "openstack-placement"
#       "app.kubernetes.io/component"  = "resource-tracking"
#       "app.kubernetes.io/managed-by" = "terraform"
#       "app.kubernetes.io/part-of"    = "openstack"
#     }
#   }
#
#   rule {
#     api_groups = each.value.api_groups
#     resources  = each.value.resources
#     verbs      = each.value.verbs
#   }
# }

# resource "kubernetes_role_binding" "placement_keystone" {
#   for_each = local.role_binding_keystone
#
#   metadata {
#     name      = each.key
#     namespace = var.keystone_namespace
#
#     labels = {
#       "app.kubernetes.io/name"       = "placement"
#       "app.kubernetes.io/instance"   = "openstack-placement"
#       "app.kubernetes.io/component"  = "resource-tracking"
#       "app.kubernetes.io/managed-by" = "terraform"
#       "app.kubernetes.io/part-of"    = "openstack"
#     }
#   }
#
#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "Role"
#     name      = each.key
#   }
#
#   dynamic "subject" {
#     for_each = each.value
#     content {
#       kind      = "ServiceAccount"
#       name      = subject.value
#       namespace = var.namespace
#     }
#   }
# }