# Copyright (C) - LOW-LAYER - 2025
# Contact : contact@low-layer.com

# =============================================================================
# VAULT PKI ENGINE - KUBERNETES CERTIFICATE AUTHORITY
# =============================================================================
# This file configures a comprehensive PKI infrastructure for Kubernetes
# clusters with multiple certificate authorities and specialized roles

# -----------------------------------------------------------------------------
# PKI SECRETS ENGINE MOUNT
# -----------------------------------------------------------------------------
# Creates PKI backend for managing Kubernetes cluster certificates
# Provides centralized certificate lifecycle management for all clusters

resource "vault_mount" "pki_kubernetes" {
  path                      = "pki-kubernetes"
  type                      = "pki"
  description               = "PKI for all Kubernetes clusters"
  max_lease_ttl_seconds     = 315360000
  default_lease_ttl_seconds = 7776000
}

resource "vault_pki_secret_backend_config_urls" "pki_kubernetes_config" {
  backend = vault_mount.pki_kubernetes.path
  issuing_certificates = [
    "https://vault.internal/v1/pki/ca",
  ]
  crl_distribution_points = [
    "https://vault.internal/v1/pki/crl"
  ]
}

# -----------------------------------------------------------------------------
# ROOT CERTIFICATE AUTHORITIES
# -----------------------------------------------------------------------------
# Creates multiple root CAs for different Kubernetes certificate hierarchies
# Follows Kubernetes PKI best practices with separated trust domains

resource "vault_pki_secret_backend_root_cert" "pki_kubernetes_low_layer_cluster" {
  backend     = vault_mount.pki_kubernetes.path
  issuer_name = "low-layer.cluster"
  type        = "internal"
  ttl         = "315360000"

  country      = "FR"
  organization = "Low-layer"
  ou           = "Infrastructure"
  common_name  = "Cluster CA"
}

resource "vault_pki_secret_backend_root_cert" "pki_kubernetes_low_layer_front_proxy" {
  backend     = vault_mount.pki_kubernetes.path
  issuer_name = "low-layer.front-proxy"
  type        = "internal"
  ttl         = "315360000"

  country      = "FR"
  organization = "Low-layer"
  ou           = "Infrastructure"
  common_name  = "Front-proxy CA"
}

resource "vault_pki_secret_backend_root_cert" "pki_kubernetes_low_layer_local" {
  backend     = vault_mount.pki_kubernetes.path
  issuer_name = "low-layer.local"
  type        = "internal"
  ttl         = "315360000"

  country      = "FR"
  organization = "Low-layer"
  ou           = "Infrastructure"
  common_name  = "Local CA"
}

# -----------------------------------------------------------------------------
# KUBERNETES API SERVER CERTIFICATE ROLE
# -----------------------------------------------------------------------------
# Configures certificate issuance for kube-apiserver components
# Includes all required SANs for API server communication

resource "vault_pki_secret_backend_role" "pki_kubernetes_low_layer_kube_apiserver_role" {
  backend    = vault_mount.pki_kubernetes.path
  issuer_ref = vault_pki_secret_backend_root_cert.pki_kubernetes_low_layer_cluster.issuer_name
  name       = "low-layer.cluster.kube-apiserver"
  country    = ["FR"]
  locality   = ["Low-layer"]
  ou         = ["Infrastructure"]

  max_ttl   = "7776000"
  key_type  = "rsa"
  key_bits  = 2048
  key_usage = ["DigitalSignature", "KeyEncipherment", "DataEncipherment"]
  ext_key_usage = ["ServerAuth"]

  allowed_domains = [
    "kube-apiserver",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster.local",
    "admin.srv*.internal",
    "admin.ctrl*.internal",
    "kube.low-layer.internal"
  ]

  allow_any_name              = false
  enforce_hostnames           = false
  allow_wildcard_certificates = false
  allow_glob_domains          = true
  allow_bare_domains          = true
  allow_ip_sans               = true
  allow_localhost             = true
  allow_subdomains            = false

  basic_constraints_valid_for_non_ca = true
}

# -----------------------------------------------------------------------------
# KUBERNETES API SERVER TO KUBELET CLIENT ROLE
# -----------------------------------------------------------------------------
# Configures client certificates for API server to kubelet communication
# Uses system:masters organization for administrative privileges

resource "vault_pki_secret_backend_role" "pki_kubernetes_low_layer_kube_apiserver_kubelet_client_role" {
  backend      = vault_mount.pki_kubernetes.path
  issuer_ref   = vault_pki_secret_backend_root_cert.pki_kubernetes_low_layer_cluster.issuer_name
  name         = "low-layer.cluster.kube-apiserver-kubelet-client"
  country      = ["FR"]
  locality     = ["Low-layer"]
  organization = ["system:masters"]

  max_ttl   = "7776000"
  key_type  = "rsa"
  key_bits  = 2048
  key_usage = ["DigitalSignature", "KeyEncipherment"]
  ext_key_usage = ["ClientAuth"]

  allowed_domains = [
    "apiserver-kubelet-client"
  ]

  allow_any_name              = false
  enforce_hostnames           = false
  allow_wildcard_certificates = false
  allow_bare_domains          = true
  allow_ip_sans               = false
  allow_localhost             = false
  allow_subdomains            = false

  basic_constraints_valid_for_non_ca = true
}

# -----------------------------------------------------------------------------
# KUBELET CERTIFICATE ROLE
# -----------------------------------------------------------------------------
# Configures certificates for kubelet components on worker nodes
# Supports both client and server authentication for kubelet operations

resource "vault_pki_secret_backend_role" "pki_kubernetes_low_layer_kubelet_role" {
  backend      = vault_mount.pki_kubernetes.path
  issuer_ref   = vault_pki_secret_backend_root_cert.pki_kubernetes_low_layer_cluster.issuer_name
  name         = "low-layer.cluster.kubelet"
  country      = ["FR"]
  locality     = ["Low-layer"]
  organization = ["system:nodes"]

  max_ttl   = "7776000"
  key_type  = "rsa"
  key_bits  = 2048
  key_usage = ["DigitalSignature", "KeyEncipherment", "DataEncipherment"]
  ext_key_usage = ["ClientAuth", "ServerAuth"]

  allowed_domains = [
    "system:node:*",
    "admin.srv*.internal",
    "admin.ctrl*.internal"
  ]

  allow_any_name              = false
  allow_glob_domains          = true
  enforce_hostnames           = false
  allow_wildcard_certificates = true
  allow_bare_domains          = false
  allow_ip_sans               = true
  allow_localhost             = true
  allow_subdomains            = false

  basic_constraints_valid_for_non_ca = true
}

# -----------------------------------------------------------------------------
# KUBERNETES CONTROLLER MANAGER CERTIFICATE ROLE
# -----------------------------------------------------------------------------
# Configures certificates for kube-controller-manager components
# Supports both client authentication and internal server communication

resource "vault_pki_secret_backend_role" "pki_kubernetes_low_layer_kube_controller_manager_role" {
  backend    = vault_mount.pki_kubernetes.path
  issuer_ref = vault_pki_secret_backend_root_cert.pki_kubernetes_low_layer_cluster.issuer_name
  name       = "low-layer.cluster.kube-controller-manager"
  country    = ["FR"]
  locality   = ["Low-layer"]
  ou         = ["system:kube-controller-manager"]

  max_ttl   = "7776000"
  key_type  = "rsa"
  key_bits  = 2048
  key_usage = ["DigitalSignature", "KeyEncipherment"]
  ext_key_usage = ["ClientAuth", "ServerAuth"]

  allowed_domains = [
    "system:kube-controller-manager",
    "kube-controller-manager",
    "controller-manager.kube-system",
    "controller-manager.kube-system.svc",
    "controller-manager.kube-system.svc.cluster.local"
  ]

  allow_any_name              = false
  enforce_hostnames           = false
  allow_wildcard_certificates = false
  allow_bare_domains          = true
  allow_ip_sans               = true
  allow_localhost             = true
  allow_subdomains            = false

  basic_constraints_valid_for_non_ca = true
}

# -----------------------------------------------------------------------------
# KUBERNETES SCHEDULER CERTIFICATE ROLE
# -----------------------------------------------------------------------------
# Configures client certificates for kube-scheduler components
# Provides authentication for scheduler to API server communication

resource "vault_pki_secret_backend_role" "pki_kubernetes_low_layer_kube_scheduler_role" {
  backend    = vault_mount.pki_kubernetes.path
  issuer_ref = vault_pki_secret_backend_root_cert.pki_kubernetes_low_layer_cluster.issuer_name
  name       = "low-layer.cluster.kube-scheduler"

  country  = ["FR"]
  locality = ["Low-layer"]
  ou       = ["system:kube-scheduler"]

  max_ttl   = "7776000"
  key_type  = "rsa"
  key_bits  = 2048
  key_usage = ["DigitalSignature", "KeyEncipherment"]
  ext_key_usage = ["ClientAuth"]

  allowed_domains = [
    "system:kube-scheduler",
  ]

  allow_any_name              = false
  enforce_hostnames           = false
  allow_wildcard_certificates = false
  allow_bare_domains          = true
  allow_ip_sans               = false
  allow_localhost             = false
  allow_subdomains            = false

  basic_constraints_valid_for_non_ca = true
}

# -----------------------------------------------------------------------------
# KUBERNETES ADMINISTRATOR CERTIFICATE ROLE
# -----------------------------------------------------------------------------
# Configures client certificates for cluster administrators
# Grants system:masters privileges for full cluster access

resource "vault_pki_secret_backend_role" "pki_kubernetes_low_layer_kube_admin_role" {
  backend      = vault_mount.pki_kubernetes.path
  issuer_ref   = vault_pki_secret_backend_root_cert.pki_kubernetes_low_layer_cluster.issuer_name
  name         = "low-layer.cluster.kube-admin"
  country      = ["FR"]
  locality     = ["Low-layer"]
  organization = ["system:masters"]

  max_ttl   = "7776000"
  key_type  = "rsa"
  key_bits  = 2048
  key_usage = ["DigitalSignature", "KeyEncipherment"]
  ext_key_usage = ["ClientAuth"]

  allowed_domains = [
    "kubernetes-admin"
  ]

  allow_any_name              = false
  enforce_hostnames           = false
  allow_wildcard_certificates = false
  allow_bare_domains          = true
  allow_ip_sans               = false
  allow_localhost             = false
  allow_subdomains            = false

  basic_constraints_valid_for_non_ca = true
}

# -----------------------------------------------------------------------------
# KUBERNETES FRONT PROXY CLIENT CERTIFICATE ROLE
# -----------------------------------------------------------------------------
# Configures certificates for front proxy client authentication
# Uses dedicated front-proxy CA for extension API server communication

resource "vault_pki_secret_backend_role" "pki_kubernetes_low_layer_kube_front_proxy_client_role" {
  backend    = vault_mount.pki_kubernetes.path
  issuer_ref = vault_pki_secret_backend_root_cert.pki_kubernetes_low_layer_front_proxy.issuer_name
  name       = "low-layer.kube-front-proxy-client"
  country    = ["FR"]
  locality   = ["Low-layer"]
  ou         = ["system:front-proxy"]

  max_ttl   = "7776000"
  key_type  = "rsa"
  key_bits  = 2048
  key_usage = ["DigitalSignature", "KeyEncipherment"]
  ext_key_usage = ["ClientAuth"]

  allowed_domains = [
    "front-proxy-client"
  ]

  allow_any_name              = false
  enforce_hostnames           = false
  allow_wildcard_certificates = false
  allow_bare_domains          = true
  allow_ip_sans               = false
  allow_localhost             = false
  allow_subdomains            = false

  basic_constraints_valid_for_non_ca = true
}

# -----------------------------------------------------------------------------
# KUBERNETES LOCAL SERVICES CERTIFICATE ROLE
# -----------------------------------------------------------------------------
# Configures certificates for cluster-local services and workloads
# Supports wildcard certificates for service mesh and internal communications

resource "vault_pki_secret_backend_role" "pki_kubernetes_low_layer_local" {
  backend      = vault_mount.pki_kubernetes.path
  issuer_ref   = vault_pki_secret_backend_root_cert.pki_kubernetes_low_layer_local.issuer_name
  name         = "low-layer.local"
  country      = ["FR"]
  organization = ["Low-layer"]
  ou           = ["Kubernetes Services"]

  max_ttl   = "7776000"
  key_type  = "rsa"
  key_bits  = 2048
  key_usage = ["DigitalSignature", "NonRepudiation", "KeyEncipherment", "DataEncipherment"]
  ext_key_usage = ["ServerAuth", "ClientAuth"]

  allowed_domains = [
    "svc.cluster.local",
    "cluster.local"
  ]

  allow_any_name              = false
  enforce_hostnames           = true
  allow_wildcard_certificates = true
  allow_bare_domains          = false
  allow_ip_sans               = true
  allow_localhost             = false
  allow_subdomains            = true

  basic_constraints_valid_for_non_ca = true
}

# =============================================================================
# OPERATIONAL NOTES
# =============================================================================
# 
# PKI Architecture:
# - Three-tier CA hierarchy: Cluster CA, Front-proxy CA, and Local CA
# - 10-year root certificate lifetime with 90-day leaf certificate rotation
# - RSA-2048 keys for compatibility across all Kubernetes versions
# 
# Certificate Roles:
# - kube-apiserver: Server certificates with comprehensive SAN coverage
# - kubelet: Dual-purpose client/server certificates for node communication
# - controller-manager: Client certificates for control plane communication
# - scheduler: Client certificates for API server access
# - admin: Client certificates with system:masters privileges
# - front-proxy-client: Dedicated certificates for extension API servers
# - local: Wildcard certificates for in-cluster service communication