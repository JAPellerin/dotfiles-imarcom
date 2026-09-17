#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice du runner : « fait » = fichier marqueur $FIXTURE_STATE_DIR/e.
MODULE_NAME="e"
MODULE_DESC="Module e dépend de zzz"
MODULE_GROUP="dev"
MODULE_DEPS="zzz"
_marker="${FIXTURE_STATE_DIR:-/tmp/dotfiles-fixtures}/e"
module_check() { [[ -f $_marker ]]; }
module_install() { :; }
module_configure() { :; }
