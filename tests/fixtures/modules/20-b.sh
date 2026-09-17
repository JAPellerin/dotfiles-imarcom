#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice du runner : « fait » = fichier marqueur $FIXTURE_STATE_DIR/b.
MODULE_NAME="b"
MODULE_DESC="Module b sans dépendance"
MODULE_GROUP="shell"
MODULE_DEPS=""
_marker="${FIXTURE_STATE_DIR:-/tmp/dotfiles-fixtures}/b"
module_check() { [[ -f $_marker ]]; }
module_install() { mkdir -p "${_marker%/*}"; log_info "install b"; touch "$_marker"; }
module_configure() { :; }
