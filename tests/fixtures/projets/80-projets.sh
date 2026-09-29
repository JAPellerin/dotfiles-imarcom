#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice : les deux commandes laissent une trace ; FIXTURE_PULL_RC fixe le code
# de projets_pull.
MODULE_NAME="projets"
MODULE_DESC="Projets factices"
MODULE_GROUP="projets"
MODULE_DEPS="base 1password"
module_check() { return 1; }
module_install() { :; }
module_configure() { :; }
projets_snapshot() { log_info "snapshot factice"; }
projets_pull() { log_info "pull factice"; return "${FIXTURE_PULL_RC:-0}"; }
