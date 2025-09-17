{{ '{{' }}- with pkiCert "pki-kubernetes/issue/low-layer.cluster.kubelet" "common_name=system:node:{{ inventory_hostname }}" "alt_names={{ inventory_hostname }},localhost" "ip_sans=127.0.0.1,{{ lookup('dig', inventory_hostname) }}" -{{ '}}' }}
{{ '{{' }} .Cert {{ '}}' }}{{ '{{' }} .CA {{ '}}' }}{{ '{{' }} .Key {{ '}}' }}
{{ '{{' }} .Cert | writeToFile "/certs/kubernetes/{{ item }}.pem" "root" "root" "0640" -{{ '}}' }}
{{ '{{' }} .Key | writeToFile "/certs/kubernetes/{{ item }}.key" "root" "root" "0600" -{{ '}}' }}
{{ '{{' }} .CA | writeToFile "/certs/kubernetes/ca.pem" "root" "root" "0640" {{ '}}' }}
{{ '{{' }}- end -{{ '}}' }}