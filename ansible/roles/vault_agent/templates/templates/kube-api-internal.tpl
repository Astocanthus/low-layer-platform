{{ '{{' }}- with pkiCert "pki/issue/low-layer.internal" "common_name={{ vip_kube_api_server['internal']['fqdn'] }}" -{{ '}}' }}
{{ '{{' }} .Cert {{ '}}' }}{{ '{{' }} .Key {{ '}}' }}
{{ '{{' }} .Cert | writeToFile "/var/lib/vault-agent/certs/kubernetes/{{ item }}.pem" "root" "root" "0640" -{{ '}}' }}
{{ '{{' }} .Key | writeToFile "/var/lib/vault-agent/certs/kubernetes/{{ item }}.key" "root" "root" "0600" -{{ '}}' }}
{{ '{{' }}- end -{{ '}}' }}