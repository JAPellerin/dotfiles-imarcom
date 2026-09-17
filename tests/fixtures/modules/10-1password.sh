#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice du runner : « fait » = fichier marqueur $FIXTURE_STATE_DIR/1password.
MODULE_NAME="1password"
MODULE_DESC="1Password app et CLI"
MODULE_GROUP="systeme"
MODULE_DEPS="base"
_marker="${FIXTURE_STATE_DIR:-/tmp/dotfiles-fixtures}/1password"
module_check() { [[ -f $_marker ]]; }
module_install() { mkdir -p "${_marker%/*}"; log_info "install 1password"; touch "$_marker"; }
module_configure() { :; }
