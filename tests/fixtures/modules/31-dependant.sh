#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice du runner : « fait » = fichier marqueur $FIXTURE_STATE_DIR/dependant.
MODULE_NAME="dependant"
MODULE_DESC="Module qui dépend de echec"
MODULE_GROUP="dev"
MODULE_DEPS="echec"
_marker="${FIXTURE_STATE_DIR:-/tmp/dotfiles-fixtures}/dependant"
module_check() { [[ -f $_marker ]]; }
module_install() { mkdir -p "${_marker%/*}"; touch "$_marker"; }
module_configure() { :; }
