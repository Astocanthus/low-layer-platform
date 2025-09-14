{{ '{{' }}- with secret "transit-k8s-low-layer/export/signing-key/k8s-service-account" -{{ '}}' }}
{{ '{{' }} index  .Data.keys "1" {{ '}}' }}
{{ '{{' }}- end -{{ '}}' }}