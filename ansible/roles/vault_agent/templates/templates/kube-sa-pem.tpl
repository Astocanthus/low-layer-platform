{{ '{{' }}- with secret "transit-k8s-low-layer/export/public-key/k8s-service-account" -{{ '}}' }}
{{ '{{' }} index  .Data.keys "1" {{ '}}' }}
{{ '{{' }}- end -{{ '}}' }}