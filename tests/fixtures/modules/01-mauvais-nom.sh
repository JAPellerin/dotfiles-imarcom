#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice invalide : MODULE_NAME ne correspond pas au fichier, groupe inconnu,
# module_configure absent.
MODULE_NAME="autre-nom"
MODULE_DESC="Nom incohérent"
MODULE_GROUP="inconnu"
MODULE_DEPS=""
module_check() { return 1; }
module_install() { :; }
