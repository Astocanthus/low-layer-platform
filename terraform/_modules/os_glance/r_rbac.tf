# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# GLANCE SERVICE ACCOUNT AND ROLE-BASED ACCESS CONTROL (RBAC)
# =============================================================================
# This file provisions service accounts and associated roles and role bindings
# required for Glance to operate across application, infrastructure, and Keystone
# namespaces. These RBAC objects ensure Glance components have necessary access
# to Kubernetes resources, without exceeding least privilege.

# -----------------------------------------------------------------------------
# SERVICE ACCOUNT DEFINITION
# -----------------------------------------------------------------------------
# Declares per-service ServiceAccounts for Glance workloads in application namespace.
# These accounts are bound to their respective Roles with defined RBAC permissions.

resource "kubernetes_service_account" "glance" {
  for_each = { for sa_name in local.sa : sa_name => sa_name }

  metadata {
    name      = each.value
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "glance"
      "app.kubernetes.io/instance"   = "openstack-glance"
      "app.kubernetes.io/component"  = "image"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }
}

# -----------------------------------------------------------------------------
# ROLE DEFINITIONS (APPLICATION NAMESPACE)
# -----------------------------------------------------------------------------
# Defines Kubernetes Roles for Glance in the application namespace.
# These roles specify rules Glance components require during operations.

resource "kubernetes_role" "glance" {
  for_each = local.role

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "glance"
      "app.kubernetes.io/instance"   = "openstack-glance"
      "app.kubernetes.io/component"  = "image"
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
# Associates each Glance Role with appropriate ServiceAccounts in the
# application namespace, granting RBAC permissions as defined in the Role.

resource "kubernetes_role_binding" "glance" {
  for_each = local.role_binding

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "glance"
      "app.kubernetes.io/instance"   = "openstack-glance"
      "app.kubernetes.io/component"  = "image"
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
# Declares roles for Glance accessing resources in infrastructure namespace.
# Useful for interacting with shared infrastructure components or services.

resource "kubernetes_role" "glance_infrastructure" {
  for_each = local.role_infrastructure

  metadata {
    name      = each.key
    namespace = var.infrastructure_namespace

    labels = {
      "app.kubernetes.io/name"       = "glance"
      "app.kubernetes.io/instance"   = "openstack-glance"
      "app.kubernetes.io/component"  = "image"
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
# Binds infrastructure-scoped roles to application ServiceAccounts, granting
# cross-namespace access for Glance to infrastructure services.

resource "kubernetes_role_binding" "glance_infrastructure" {
  for_each = local.role_binding_infrastructure

  metadata {
    name      = each.key
    namespace = var.infrastructure_namespace

    labels = {
      "app.kubernetes.io/name"       = "glance"
      "app.kubernetes.io/instance"   = "openstack-glance"
      "app.kubernetes.io/component"  = "image"
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
# KEYSTONE ROLE DEFINITIONS (IN KEYSTONE NAMESPACE)
# -----------------------------------------------------------------------------
# Declares roles used by Glance to access Keystone-specific APIs and resources
# within the Keystone namespace.

resource "kubernetes_role" "glance_keystone" {
  for_each = local.role_keystone

  metadata {
    name      = each.key
    namespace = var.keystone_namespace

    labels = {
      "app.kubernetes.io/name"       = "glance"
      "app.kubernetes.io/instance"   = "openstack-glance"
      "app.kubernetes.io/component"  = "image"
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
# ROLE BINDINGS (KEYSTONE NAMESPACE)
# -----------------------------------------------------------------------------
# Binds the Keystone namespace roles to Glance service accounts to allow
# cross-namespace interaction with Keystone components.

resource "kubernetes_role_binding" "glance_keystone" {
  for_each = local.role_binding_keystone

  metadata {
    name      = each.key
    namespace = var.keystone_namespace

    labels = {
      "app.kubernetes.io/name"       = "glance"
      "app.kubernetes.io/instance"   = "openstack-glance"
      "app.kubernetes.io/component"  = "image"
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