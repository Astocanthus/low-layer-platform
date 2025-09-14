{{ '{{' }}- with pkiCert "pki-kubernetes/issue/low-layer.cluster.kube-apiserver" "common_name=kube-apiserver" "alt_names=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster.local,localhost,{{ inventory_hostname }},{{ vip_kube_api_server["internal"]["fqdn"] }}" "ip_sans=127.0.0.1,10.96.0.1" -{{ '}}' }}
{{ '{{' }} .Cert {{ '}}' }}{{ '{{' }} .CA {{ '}}' }}{{ '{{' }} .Key {{ '}}' }}
{{ '{{' }} .Cert | writeToFile "/var/lib/vault-agent/certs/kubernetes/{{ item }}.pem" "root" "root" "0640" -{{ '}}' }}
{{ '{{' }} .Key | writeToFile "/var/lib/vault-agent/certs/kubernetes/{{ item }}.key" "root" "root" "0600" -{{ '}}' }}
{{ '{{' }} .CA | writeToFile "/var/lib/vault-agent/certs/kubernetes/ca.pem" "root" "root" "0640" {{ '}}' }}
{{ '{{' }}- end -{{ '}}' }}