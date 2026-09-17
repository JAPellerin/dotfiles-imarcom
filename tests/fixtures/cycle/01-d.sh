#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice du runner : « fait » = fichier marqueur $FIXTURE_STATE_DIR/d.
MODULE_NAME="d"
MODULE_DESC="Module d dépend de c"
MODULE_GROUP="dev"
MODULE_DEPS="c"
_marker="${FIXTURE_STATE_DIR:-/tmp/dotfiles-fixtures}/d"
module_check() { [[ -f $_marker ]]; }
module_install() { :; }
module_configure() { :; }
