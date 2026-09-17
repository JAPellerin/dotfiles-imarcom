#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice du runner : « fait » = fichier marqueur $FIXTURE_STATE_DIR/echec.
MODULE_NAME="echec"
MODULE_DESC="Module dont l installation échoue"
MODULE_GROUP="dev"
MODULE_DEPS="base"
_marker="${FIXTURE_STATE_DIR:-/tmp/dotfiles-fixtures}/echec"
module_check() { [[ -f $_marker ]]; }
module_install() { mkdir -p "${_marker%/*}"; log_info "install echec"; run sh -c "echo detail-echec; exit 5"; }
module_configure() { :; }
