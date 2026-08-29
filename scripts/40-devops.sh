#!/usr/bin/env bash
# 40-devops.sh — cloud-native / DevOps toolbox, all installed locally.
# kubectl, kubectx, helm, k9s, stern, kustomize, argocd, vault, terraform,
# opentofu, awscli, azure-cli, sops, dive — plus gcloud and OrbStack for local
# Docker + Kubernetes. The list (including the hashicorp tap) lives in the
# Brewfile under `#: group devops`.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_macos; require_brew

install_brewfile_group devops

ok "DevOps toolbox installed."
info "K8s/IaC: ${C_BOLD}k9s${C_RESET}, ${C_BOLD}kubectx${C_RESET}/${C_BOLD}kubens${C_RESET}, ${C_BOLD}argocd version${C_RESET}, ${C_BOLD}vault -version${C_RESET}, ${C_BOLD}terraform -version${C_RESET}"
info "Clouds: ${C_BOLD}aws${C_RESET} (configure), ${C_BOLD}az login${C_RESET}, ${C_BOLD}gcloud init${C_RESET}"
info "Launch ${C_BOLD}OrbStack${C_RESET} once to start the Docker engine; enable Kubernetes in its settings for a local cluster."
