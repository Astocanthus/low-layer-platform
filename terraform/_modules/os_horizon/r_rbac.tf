# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# HORIZON SERVICE ACCOUNT AND ROLE-BASED ACCESS CONTROL (RBAC)
# =============================================================================
# This file provisions the required ServiceAccounts and Roles/RoleBindings
# for the Horizon component, both in the main application namespace and in 
# infrastructure/Keystone namespaces. These RBAC objects ensure that Horizon
# can interact with Kubernetes components according to the principle of 
# least privilege.

# -----------------------------------------------------------------------------
# SERVICE ACCOUNT DEFINITION
# -----------------------------------------------------------------------------
# Declares ServiceAccounts used by Horizon in the application namespace.

resource "kubernetes_service_account" "horizon" {
  for_each = { for sa_name in local.service_accounts : sa_name => sa_name }

  metadata {
    name      = each.value
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "horizon"
      "app.kubernetes.io/instance"   = "openstack-horizon"
      "app.kubernetes.io/component"  = "dashboard"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }
}

# -----------------------------------------------------------------------------
# ROLE DEFINITIONS (APPLICATION NAMESPACE)
# -----------------------------------------------------------------------------
# Defines Roles granting Horizon access to resources scoped to the
# application namespace.

resource "kubernetes_role" "horizon" {
  for_each = local.roles

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "horizon"
      "app.kubernetes.io/instance"   = "openstack-horizon"
      "app.kubernetes.io/component"  = "dashboard"
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
# Binds Horizon Roles to ServiceAccounts, granting access in the 
# application namespace.

resource "kubernetes_role_binding" "horizon" {
  for_each = local.role_bindings

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "horizon"
      "app.kubernetes.io/instance"   = "openstack-horizon"
      "app.kubernetes.io/component"  = "dashboard"
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
# ROLE DEFINITIONS (INFRASTRUCTURE NAMESPACE)
# -----------------------------------------------------------------------------
# Defines Roles used by Horizon to access shared infrastructure services.

resource "kubernetes_role" "horizon_infrastructure" {
  for_each = local.role_infrastructure

  metadata {
    name      = each.key
    namespace = var.infrastructure_namespace

    labels = {
      "app.kubernetes.io/name"       = "horizon"
      "app.kubernetes.io/instance"   = "openstack-horizon"
      "app.kubernetes.io/component"  = "dashboard"
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
# Binds infrastructure namespace Roles to Horizon ServiceAccounts 
# from the application namespace.

resource "kubernetes_role_binding" "horizon_infrastructure" {
  for_each = local.role_binding_infrastructure

  metadata {
    name      = each.key
    namespace = var.infrastructure_namespace

    labels = {
      "app.kubernetes.io/name"       = "horizon"
      "app.kubernetes.io/instance"   = "openstack-horizon"
      "app.kubernetes.io/component"  = "dashboard"
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
# ROLE DEFINITIONS (KEYSTONE NAMESPACE)
# -----------------------------------------------------------------------------
# Defines Roles granting Horizon scoped access to Keystone namespace APIs.

resource "kubernetes_role" "horizon_keystone" {
  for_each = local.keystone_roles

  metadata {
    name      = each.key
    namespace = var.keystone_namespace

    labels = {
      "app.kubernetes.io/name"       = "horizon"
      "app.kubernetes.io/instance"   = "openstack-horizon"
      "app.kubernetes.io/component"  = "dashboard"
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
# Grants Horizon ServiceAccounts access to Keystone roles using bindings
# from the keystone_namespace.

resource "kubernetes_role_binding" "horizon_keystone" {
  for_each = local.keystone_role_bindings

  metadata {
    name      = each.key
    namespace = var.keystone_namespace

    labels = {
      "app.kubernetes.io/name"       = "horizon"
      "app.kubernetes.io/instance"   = "openstack-horizon"
      "app.kubernetes.io/component"  = "dashboard"
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