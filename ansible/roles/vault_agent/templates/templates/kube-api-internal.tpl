{{ '{{' }}- with pkiCert "pki/issue/low-layer.internal" "common_name={{ vip_kubernetes_api_server['internal']['fqdn'] }}" -{{ '}}' }}
{{ '{{' }} .Cert {{ '}}' }}{{ '{{' }} .Key {{ '}}' }}
{{ '{{' }} .Cert | writeToFile "/certs/kubernetes/{{ item }}.pem" "root" "root" "0640" -{{ '}}' }}
{{ '{{' }} .Key | writeToFile "/certs/kubernetes/{{ item }}.key" "root" "root" "0600" -{{ '}}' }}
{{ '{{' }}- end -{{ '}}' }}