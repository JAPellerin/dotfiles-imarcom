#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice du runner : « fait » = fichier marqueur $FIXTURE_STATE_DIR/base.
MODULE_NAME="base"
MODULE_DESC="Paquets de base"
MODULE_GROUP="systeme"
MODULE_DEPS=""
_marker="${FIXTURE_STATE_DIR:-/tmp/dotfiles-fixtures}/base"
module_check() { [[ -f $_marker ]]; }
module_install() { mkdir -p "${_marker%/*}"; log_info "install base"; touch "$_marker"; }
module_configure() { :; }
