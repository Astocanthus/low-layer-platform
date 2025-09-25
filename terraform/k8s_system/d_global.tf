# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# =============================================================================
# GLOBAL DATA SOURCES
# =============================================================================
# Centralized data source definitions for reuse across Terraform configurations
# Provides consistent references to external resources and services

# -----------------------------------------------------------------------------
# KUBERNETES CLUSTER DATA
# -----------------------------------------------------------------------------
# References to existing Kubernetes cluster resources

data "kubernetes_service" "internal_lb" {
  metadata {
    name      = "istio-ingressgateway"
    namespace = "istio-proxy-internal"
  }
}

# -----------------------------------------------------------------------------
# VAULT PKI DATA SOURCES
# -----------------------------------------------------------------------------
# Certificate authority and PKI backend references

data "vault_pki_secret_backend_issuer" "local_ca" {
  backend    = "pki-kubernetes"
  issuer_ref = "low-layer.local"
}