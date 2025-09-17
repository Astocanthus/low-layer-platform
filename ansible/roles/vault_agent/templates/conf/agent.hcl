# Copyright (C) - LOW-LAYER
# Contact : contact@low-layer.com

# ============================================================================

# Vault connection configuration
vault {
  address = "https://vault.internal"

  retry {
    num_retries = 5
  }
}

# Automatic authentication via AppRole
auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      # Files containing the AppRole credentials
      role_id_file_path   = "/run/secrets/vault_role_id"
      secret_id_file_path = "/run/secrets/vault_secret_id"
      # Keep the secret_id to avoid re-authentication
      remove_secret_id_file_after_reading = false
    }
  }
}

# Enable mlock to prevent swapping on the host (avoid token leakage to disk)
disable_mlock = true

{% for tpl in vault_kubernetes_templates %}
template {
  source      = "/vault/templates/{{ tpl }}.tpl"
  destination = "/certs/kubernetes/{{ tpl }}.bundle.pem"
  perms       = "0600" 
  error_on_missing_key = true
}
{% endfor %}

{% if vault_transit_kubernetes_sa %}
template {
  source      = "/vault/templates/kube-sa-key.tpl"
  destination = "/certs/kubernetes/sa.key"
  perms       = "0600" 
  error_on_missing_key = true
}
template {
  source      = "/vault/templates/kube-sa-pem.tpl"
  destination = "/certs/kubernetes/sa.pem"
  perms       = "0640" 
  error_on_missing_key = true
}
{% endif %}