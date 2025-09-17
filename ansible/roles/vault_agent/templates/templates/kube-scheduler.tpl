{{ '{{' }}- with pkiCert "pki-kubernetes/issue/low-layer.cluster.kube-scheduler" "common_name=system:kube-scheduler" -{{ '}}' }}
{{ '{{' }} .Cert {{ '}}' }}{{ '{{' }} .CA {{ '}}' }}{{ '{{' }} .Key {{ '}}' }}
{{ '{{' }} .Cert | writeToFile "/certs/kubernetes/{{ item }}.pem" "root" "root" "0640" -{{ '}}' }}
{{ '{{' }} .Key | writeToFile "/certs/kubernetes/{{ item }}.key" "root" "root" "0600" -{{ '}}' }}
{{ '{{' }} .CA | writeToFile "/certs/kubernetes/ca.pem" "root" "root" "0640" {{ '}}' }}
{{ '{{' }}- end -{{ '}}' }}