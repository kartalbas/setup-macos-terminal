#!/usr/bin/env bash
# 40-devops.sh — cloud-native / DevOps toolbox, all installed locally.
# kubectl, kubectx, helm, k9s, stern, kustomize, argocd, vault, terraform,
# opentofu, awscli, sops, dive — plus OrbStack for local Docker + Kubernetes.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos; require_brew

# HashiCorp tap (vault/terraform live here since the license change) ----------
if brew tap | grep -q '^hashicorp/tap$'; then
  skip "tap hashicorp/tap"
else
  info "Tapping hashicorp/tap..."; run brew tap hashicorp/tap
fi

DEVOPS_FORMULAE=(
  kubernetes-cli kubectx kubecolor helm k9s stern kustomize
  argocd
  hashicorp/tap/vault hashicorp/tap/terraform opentofu
  sops dive
  awscli azure-cli            # AWS (aws) + Azure (az) CLIs
)

for f in "${DEVOPS_FORMULAE[@]}"; do
  # brew list checks against the leaf name (e.g. vault, terraform)
  leaf="${f##*/}"
  if brew_has_formula "$leaf"; then skip "$leaf"; else
    info "Installing $f..."; run brew install "$f"
  fi
done

# Google Cloud SDK (cask) → gcloud / gsutil / bq ------------------------------
if brew_has_cask google-cloud-sdk; then
  skip "google-cloud-sdk"
else
  info "Installing Google Cloud SDK (gcloud)..."
  run brew install --cask google-cloud-sdk
  info "Authenticate later with: ${C_BOLD}gcloud init${C_RESET}"
fi

# OrbStack: local Docker engine + one-click Kubernetes (Docker Desktop alt) ---
if brew_has_cask orbstack; then
  skip "orbstack"
else
  info "Installing OrbStack (local Docker + Kubernetes)..."
  run brew install --cask orbstack
  info "Launch OrbStack once to start the Docker engine; enable Kubernetes in its settings if you want a local cluster."
fi

ok "DevOps toolbox installed."
info "K8s/IaC: ${C_BOLD}k9s${C_RESET}, ${C_BOLD}kubectx${C_RESET}/${C_BOLD}kubens${C_RESET}, ${C_BOLD}argocd version${C_RESET}, ${C_BOLD}vault -version${C_RESET}, ${C_BOLD}terraform -version${C_RESET}"
info "Clouds: ${C_BOLD}aws${C_RESET} (configure), ${C_BOLD}az login${C_RESET}, ${C_BOLD}gcloud init${C_RESET}"
