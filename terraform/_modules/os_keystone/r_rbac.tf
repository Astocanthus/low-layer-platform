# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# KEYSTONE SERVICE ACCOUNT AND ROLE-BASED ACCESS CONTROL (RBAC)
# =============================================================================
# This file provisions the required service accounts and RBAC rules for 
# Keystone to operate in both the application namespace and infrastructure 
# namespace within Kubernetes. It defines roles, bindings, and accounts 
# to allow proper cluster access for Keystone's components and interactions.

# -----------------------------------------------------------------------------
# SERVICE ACCOUNT DEFINITION
# -----------------------------------------------------------------------------
# Declares a set of ServiceAccounts to be used by Keystone workloads.
# Each account is associated with the main application namespace provided via variable.

resource "kubernetes_service_account" "keystone" {
  for_each = { for sa_name in local.sa : sa_name => sa_name }

  metadata {
    name      = each.value
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "identity"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }
}

# -----------------------------------------------------------------------------
# ROLE DEFINITIONS (NAMESPACE-SCOPED)
# -----------------------------------------------------------------------------
# Defines Kubernetes Role resources that determine access rights for
# each specific Keystone capability within the namespace. These are 
# linked later through corresponding RoleBindings.

resource "kubernetes_role" "keystone" {
  for_each = local.role

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "identity"
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
# Binds above Roles to specific ServiceAccounts, granting the required
# permissions scoped to the application namespace. Uses dynamic subjects
# to bind multiple accounts when needed.

resource "kubernetes_role_binding" "keystone" {
  for_each = local.role_binding

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "identity"
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
# INFRASTRUCTURE ROLE DEFINITIONS
# -----------------------------------------------------------------------------
# Similar to the application namespace roles, but targeted at infrastructure
# components Keystone may need access to in a separate namespace.

resource "kubernetes_role" "keystone_infrastructure" {
  for_each = local.role_infrastructure

  metadata {
    name      = each.key
    namespace = var.infrastructure_namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "identity"
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
# ROLE BINDINGS (INFRASTRUCTURE NAMESPACE)
# -----------------------------------------------------------------------------
# Grants access to resources in the infrastructure namespace by binding 
# the roles defined above to ServiceAccounts from the application namespace.

resource "kubernetes_role_binding" "keystone_infrastructure" {
  for_each = local.role_binding_infrastructure

  metadata {
    name      = each.key
    namespace = var.infrastructure_namespace

    labels = {
      "app.kubernetes.io/name"       = "keystone"
      "app.kubernetes.io/instance"   = "openstack-keystone"
      "app.kubernetes.io/component"  = "identity"
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