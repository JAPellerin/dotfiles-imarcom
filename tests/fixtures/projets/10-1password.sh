#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice : « fait » = marqueur $FIXTURE_STATE_DIR/1password ; FIXTURE_OP_FAIL=1
# fait échouer son installation (installation qui demanderait sudo).
MODULE_NAME="1password"
MODULE_DESC="1Password factice"
MODULE_GROUP="systeme"
MODULE_DEPS="base"
_marker="${FIXTURE_STATE_DIR:-/tmp/dotfiles-fixtures}/1password"
module_check() { [[ -f $_marker ]]; }
module_install() {
  [[ ${FIXTURE_OP_FAIL:-0} == 1 ]] && { log_error "installation factice refusée"; return 1; }
  mkdir -p "${_marker%/*}"; log_info "install 1password"; touch "$_marker"
}
module_configure() { :; }
