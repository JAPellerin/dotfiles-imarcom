#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice invalide : virgule dans MODULE_DESC (casse la présélection du menu).
MODULE_NAME="virgule"
MODULE_DESC="curl, git et jq"
MODULE_GROUP="systeme"
MODULE_DEPS=""
module_check() { return 1; }
module_install() { :; }
module_configure() { :; }
