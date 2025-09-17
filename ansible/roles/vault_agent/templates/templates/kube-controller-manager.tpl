{{ '{{' }}- with pkiCert "pki-kubernetes/issue/low-layer.cluster.kube-controller-manager" "common_name=system:kube-controller-manager" "alt_names=controller-manager.kube-system,localhost"  "ip_sans=127.0.0.1" -{{ '}}' }}
{{ '{{' }} .Cert {{ '}}' }}{{ '{{' }} .CA {{ '}}' }}{{ '{{' }} .Key {{ '}}' }}
{{ '{{' }} .Cert | writeToFile "/certs/kubernetes/{{ item }}.pem" "root" "root" "0640" -{{ '}}' }}
{{ '{{' }} .Key | writeToFile "/certs/kubernetes/{{ item }}.key" "root" "root" "0600" -{{ '}}' }}
{{ '{{' }} .CA | writeToFile "/certs/kubernetes/ca.pem" "root" "root" "0640" {{ '}}' }}
{{ '{{' }}- end -{{ '}}' }}