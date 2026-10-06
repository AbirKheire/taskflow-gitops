#!/usr/bin/env bash
# Envoie N requêtes au service depuis l'intérieur du cluster et compte les réponses
# par version et par code HTTP. Montre la répartition du trafic pendant un déploiement.
# Usage : ./scripts/observe.sh [service] [nombre]     ex. ./scripts/observe.sh taskflow 40
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
SERVICE="${1:-taskflow}"
COUNT="${2:-40}"
kubectl -n taskflow run "observe-$(date +%s)" --rm -i --restart=Never --quiet \
  --image=curlimages/curl:latest --command -- sh -c "
for i in \$(seq 1 ${COUNT}); do
  r=\$(curl -s -m 5 -w ' %{http_code}' http://${SERVICE}/)
  v=\$(echo \"\$r\" | sed -n 's/.*\"version\":\"\\([^\"]*\\)\".*/\\1/p')
  echo \"version=\${v:-aucune} http=\${r##* }\"
done | sort | uniq -c"
