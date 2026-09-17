#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice du runner : « fait » = fichier marqueur $FIXTURE_STATE_DIR/c.
MODULE_NAME="c"
MODULE_DESC="Module c dépend de d"
MODULE_GROUP="dev"
MODULE_DEPS="d"
_marker="${FIXTURE_STATE_DIR:-/tmp/dotfiles-fixtures}/c"
module_check() { [[ -f $_marker ]]; }
module_install() { :; }
module_configure() { :; }
