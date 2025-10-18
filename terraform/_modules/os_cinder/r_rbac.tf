# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# CINDER SERVICE ACCOUNT AND ROLE-BASED ACCESS CONTROL (RBAC)
# =============================================================================
# This file provisions the required ServiceAccounts and RBAC rules for Cinder.
# It creates roles and bindings that define access rights for Cinder components 
# within the application, infrastructure, and Keystone namespaces.

# -----------------------------------------------------------------------------
# SERVICE ACCOUNT DEFINITION
# -----------------------------------------------------------------------------
# Defines the set of ServiceAccounts to be used by Cinder workloads.
# These accounts reside in the application namespace and are associated later 
# with RBAC permission bindings.

resource "kubernetes_service_account" "cinder" {
  for_each = { for sa_name in local.sa : sa_name => sa_name }

  metadata {
    name      = each.value
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "volume"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }
}

# -----------------------------------------------------------------------------
# ROLE DEFINITIONS (APPLICATION NAMESPACE)
# -----------------------------------------------------------------------------
# Defines Kubernetes Roles granting specific access control to Cinder components 
# within the main application namespace.

resource "kubernetes_role" "cinder" {
  for_each = local.role

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "volume"
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
# Associates Roles with the previously defined ServiceAccounts 
# to grant required application namespace permissions.

resource "kubernetes_role_binding" "cinder" {
  for_each = local.role_binding

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "volume"
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
# Defines Cinder-specific Roles within the infrastructure namespace
# required for access to shared infrastructure components.

resource "kubernetes_role" "cinder_infrastructure" {
  for_each = local.role_infrastructure

  metadata {
    name      = each.key
    namespace = var.infrastructure_namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "volume"
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
# Grants access to the infrastructure namespace by binding Roles
# to ServiceAccounts from the application namespace.

resource "kubernetes_role_binding" "cinder_infrastructure" {
  for_each = local.role_binding_infrastructure

  metadata {
    name      = each.key
    namespace = var.infrastructure_namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "volume"
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
# KEYSTONE ROLE DEFINITIONS FOR CINDER
# -----------------------------------------------------------------------------
# Declares Roles that allow Cinder to interact with Keystone,
# defined in the Keystone namespace.

resource "kubernetes_role" "cinder_keystone" {
  for_each = local.role_keystone

  metadata {
    name      = each.key
    namespace = var.keystone_namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "volume"
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
# Binds the Keystone-specific Roles to Cinder ServiceAccounts
# enabling secure communication between components.

resource "kubernetes_role_binding" "cinder_keystone" {
  for_each = local.role_binding_keystone

  metadata {
    name      = each.key
    namespace = var.keystone_namespace

    labels = {
      "app.kubernetes.io/name"       = "cinder"
      "app.kubernetes.io/instance"   = "openstack-cinder"
      "app.kubernetes.io/component"  = "volume"
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