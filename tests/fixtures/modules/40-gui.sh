#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice du runner : « fait » = fichier marqueur $FIXTURE_STATE_DIR/gui.
MODULE_NAME="gui"
MODULE_DESC="Application de bureau"
MODULE_GROUP="bureau"
MODULE_DEPS="base"
MODULE_NEEDS_GUI=1
_marker="${FIXTURE_STATE_DIR:-/tmp/dotfiles-fixtures}/gui"
module_check() { [[ -f $_marker ]]; }
module_install() { mkdir -p "${_marker%/*}"; touch "$_marker"; }
module_configure() { :; }
