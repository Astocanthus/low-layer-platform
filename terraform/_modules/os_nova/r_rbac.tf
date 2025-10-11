# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# NOVA SERVICE ACCOUNT AND ROLE-BASED ACCESS CONTROL (RBAC)
# =============================================================================
# This file provisions ServiceAccounts and RBAC rules for Nova to operate 
# across multiple Kubernetes namespaces. It includes roles and bindings 
# for application-level, infrastructure-level, and Keystone-level access.

# -----------------------------------------------------------------------------
# SERVICE ACCOUNT DEFINITIONS
# -----------------------------------------------------------------------------
# Declares ServiceAccounts used by Nova workloads
# All accounts are created in the application namespace

resource "kubernetes_service_account" "nova" {
  for_each = { for sa_name in local.service_accounts : sa_name => sa_name }

  metadata {
    name      = each.value
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "compute"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "openstack"
    }
  }
}

# -----------------------------------------------------------------------------
# ROLE DEFINITIONS (APPLICATION NAMESPACE)
# -----------------------------------------------------------------------------
# Defines fine-grained access controls for Nova in the application namespace

resource "kubernetes_role" "nova" {
  for_each = local.role

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "compute"
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
# Binds application-level roles to the appropriate service accounts

resource "kubernetes_role_binding" "nova" {
  for_each = local.role_binding

  metadata {
    name      = each.key
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "compute"
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
# Defines roles required by Nova to access resources in the infrastructure namespace

resource "kubernetes_role" "nova_infrastructure" {
  for_each = local.role_infrastructure

  metadata {
    name      = each.key
    namespace = var.infrastructure_namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "compute"
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
# Binds infrastructure roles to Nova's service accounts from app namespace

resource "kubernetes_role_binding" "nova_infrastructure" {
  for_each = local.role_binding_infrastructure

  metadata {
    name      = each.key
    namespace = var.infrastructure_namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "compute"
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
# Nova needs limited access to Keystone resources, defined here

resource "kubernetes_role" "nova_keystone" {
  for_each = local.role_keystone

  metadata {
    name      = each.key
    namespace = var.keystone_namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "compute"
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
# Grants Nova workloads in app namespace access to Keystone namespace roles

resource "kubernetes_role_binding" "nova_keystone" {
  for_each = local.role_binding_keystone

  metadata {
    name      = each.key
    namespace = var.keystone_namespace

    labels = {
      "app.kubernetes.io/name"       = "nova"
      "app.kubernetes.io/instance"   = "openstack-nova"
      "app.kubernetes.io/component"  = "compute"
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