#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice du runner : « fait » = fichier marqueur $FIXTURE_STATE_DIR/a.
MODULE_NAME="a"
MODULE_DESC="Module a qui dépend de b"
MODULE_GROUP="shell"
MODULE_DEPS="b"
_marker="${FIXTURE_STATE_DIR:-/tmp/dotfiles-fixtures}/a"
module_check() { [[ -f $_marker ]]; }
module_install() { mkdir -p "${_marker%/*}"; log_info "install a"; touch "$_marker"; }
module_configure() { manual_step "Redémarrer la session pour a"; }
