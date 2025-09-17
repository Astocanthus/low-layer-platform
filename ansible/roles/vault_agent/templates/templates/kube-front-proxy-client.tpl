{{ '{{' }}- with pkiCert "pki-kubernetes/issue/low-layer.kube-front-proxy-client" "common_name=front-proxy-client" -{{ '}}' }}
{{ '{{' }} .Cert {{ '}}' }}{{ '{{' }} .CA {{ '}}' }}{{ '{{' }} .Key {{ '}}' }}
{{ '{{' }} .Cert | writeToFile "/certs/kubernetes/{{ item }}.pem" "root" "root" "0640" -{{ '}}' }}
{{ '{{' }} .Key | writeToFile "/certs/kubernetes/{{ item }}.key" "root" "root" "0600" -{{ '}}' }}
{{ '{{' }} .CA | writeToFile "/certs/kubernetes/ca-front-proxy.pem" "root" "root" "0640" {{ '}}' }}
{{ '{{' }}- end -{{ '}}' }}