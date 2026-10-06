#!/usr/bin/env bash
# Ouvre l'interface d'Argo CD sur https://localhost:8080 (Ctrl+C pour arrêter).
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
PASSWORD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo "Argo CD : https://localhost:8080  (utilisateur admin, mot de passe ${PASSWORD})"
echo "Le navigateur signale un certificat non reconnu : c'est normal en local, acceptez-le."
kubectl -n argocd port-forward svc/argocd-server 8080:443
