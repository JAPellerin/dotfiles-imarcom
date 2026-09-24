#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/62-thunderbird.sh — Thunderbird depuis l'archive officielle de Mozilla,
# dans la langue d'Ubuntu, installé dans le dossier personnel (méthode « dossier
# personnel »), dictionnaires anglais (Canada) et français pré-installés par
# stratégie d'entreprise.
#   https://support.mozilla.org/kb/installing-thunderbird-linux
#   https://github.com/thunderbird/policy-templates (ExtensionSettings)
#
# Sur Ubuntu 26.04, le paquet `thunderbird` n'est qu'une transition vers le snap,
# et le dépôt apt de Mozilla ne publie pas Thunderbird : l'archive .tar.xz est le
# seul format officiel. Installée dans ~/.local/share, elle appartient à
# l'utilisateur et la mise à jour intégrée de Thunderbird peut y écrire (D2) ;
# aucun sudo. Commande dans ~/.local/bin (d'où la dépendance à `shell`, D4b),
# lanceur rendu depuis le fichier .desktop de Mozilla (D3). Langue de la version
# tirée de celle d'Ubuntu, constatée dans l'installation et rétablie par une
# réinstallation si elle diffère (D6) ; dictionnaires par stratégie d'entreprise
# dans /etc, seule écriture système du module (D7).
# Voir openspec/specs/module-thunderbird/spec.md et openspec/changes/archive/2026-09-24-thunderbird/design.md.
MODULE_NAME="thunderbird"
MODULE_DESC="Thunderbird (archive officielle de Mozilla dans le dossier personnel ; langue d'Ubuntu) ; dictionnaires en-CA et fr"
MODULE_GROUP="apps"
MODULE_DEPS="base shell"
MODULE_NEEDS_GUI=1

# Mozilla redirige vers la dernière version publiée (D1) ; @LANG@ devient la
# langue retenue (D6). Surchargeable (tests).
THUNDERBIRD_URL="${THUNDERBIRD_URL:-https://download.mozilla.org/?product=thunderbird-latest&os=linux64&lang=@LANG@}"
# Langues dans lesquelles Mozilla publie Thunderbird (product-details,
# thunderbird_primary_builds.json, relevé du 24 sept 2026) : pas de fr-CA.
THUNDERBIRD_LOCALES="af ar ast be bg br ca cak cs cy da de dsb el en-CA en-GB en-US es-AR es-ES es-MX et eu fi fr fy-NL ga-IE gd gl he hr hsb hu hy-AM id is it ja ka kab kk ko lt lv mk ms nb-NO nl nn-NO pa-IN pl pt-BR pt-PT rm ro ru sk sl sq sr sv-SE th tr uk uz vi zh-CN zh-TW"
THUNDERBIRD_DEFAULT_LOCALE="en-US"
THUNDERBIRD_DIR="$HOME/.local/share/thunderbird"
THUNDERBIRD_BIN="$HOME/.local/bin/thunderbird"
THUNDERBIRD_APPS_DIR="$HOME/.local/share/applications"
THUNDERBIRD_DESKTOP="$THUNDERBIRD_APPS_DIR/thunderbird.desktop"
THUNDERBIRD_DESKTOP_SRC="config/thunderbird/thunderbird.desktop"
# Stratégie d'entreprise des dictionnaires (D7) ; racine surchargeable (tests),
# comme NAV_ETC pour navigateur.
THUNDERBIRD_ETC="${THUNDERBIRD_ETC:-}"
THUNDERBIRD_POLICIES="$THUNDERBIRD_ETC/etc/thunderbird/policies/policies.json"
THUNDERBIRD_POLICIES_SRC="config/thunderbird/policies.json"
THUNDERBIRD_ACCOUNTS_MANUAL="Ouvrir Thunderbird (menu des applications) et ajouter les comptes de courriel et les agendas Google."

# _thunderbird_desktop : le gabarit rendu sur stdout, @THUNDERBIRD_DIR@ remplacé
# par le chemin absolu d'installation (remplacement entre guillemets : un « & »
# dans le chemin reste littéral).
_thunderbird_desktop() {
  local tpl
  tpl=$(<"$DOTFILES_DIR/$THUNDERBIRD_DESKTOP_SRC") || return 1
  printf '%s\n' "${tpl//@THUNDERBIRD_DIR@/"$THUNDERBIRD_DIR"}"
}

# _thunderbird_wanted_lang : la langue de Thunderbird qui correspond à celle
# d'Ubuntu (D6). Langue d'Ubuntu : premier élément de LANGUAGE, sinon LC_ALL,
# LC_MESSAGES, LANG (ordre de gettext) ; ll_CC.codeset@mod → ll-CC s'il est
# publié, sinon ll, sinon en-US (fr_CA → fr : Mozilla ne publie pas de fr-CA).
_thunderbird_wanted_lang() {
  local raw=${LANGUAGE:-} code
  raw=${raw%%:*}
  [[ -z $raw || $raw == C || $raw == POSIX ]] && raw=${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}
  raw=${raw%%.*}; raw=${raw%%@*}
  for code in "${raw/_/-}" "${raw%%_*}"; do
    [[ -n $code && " $THUNDERBIRD_LOCALES " == *" $code "* ]] && { printf '%s\n' "$code"; return 0; }
  done
  printf '%s\n' "$THUNDERBIRD_DEFAULT_LOCALE"
}

# _thunderbird_installed_lang <dossier> : langue de la version installée dans
# <dossier>, premier élément de res/multilocale.txt dans omni.ja (« fr,en-US »
# pour la version française). Rien sur stdout, et 1, si c'est illisible.
_thunderbird_installed_lang() {
  local list
  list=$(unzip -p -- "$1/omni.ja" res/multilocale.txt 2>/dev/null) || return 1
  list=${list%%,*}; list=${list//[[:space:]]/}
  [[ -n $list ]] || return 1
  printf '%s\n' "$list"
}

# Déjà fait = binaire exécutable dans le dossier d'installation, dans la langue
# d'Ubuntu (D6), commande liée à ce binaire, lanceur identique au gabarit rendu
# (D4), stratégie des dictionnaires identique au dépôt (D7). La version n'est pas
# vérifiée : Thunderbird se met à jour lui-même.
module_check() {
  [[ -x $THUNDERBIRD_DIR/thunderbird ]] || return 1
  [[ $(_thunderbird_installed_lang "$THUNDERBIRD_DIR") == "$(_thunderbird_wanted_lang)" ]] || return 1
  [[ -L $THUNDERBIRD_BIN && $(readlink -- "$THUNDERBIRD_BIN") == "$THUNDERBIRD_DIR/thunderbird" ]] || return 1
  # cmp rend 2 si le lanceur manque : ramené à 1, seul code « à faire » du contrat.
  cmp -s -- <(_thunderbird_desktop) "$THUNDERBIRD_DESKTOP" || return 1
  cmp -s -- "$DOTFILES_DIR/$THUNDERBIRD_POLICIES_SRC" "$THUNDERBIRD_POLICIES" || return 1
}

# Archive téléchargée puis extraite dans un dossier temporaire du même système
# de fichiers que la destination, renommé seulement s'il contient
# thunderbird/thunderbird : jamais de dossier d'installation à moitié écrit (D1).
# Installation dans une autre langue que celle d'Ubuntu : remplacée par la bonne,
# l'ancienne mise de côté dans le temporaire puis retirée, remise en place si
# l'échange échoue ; le profil (~/.config/thunderbird) n'est pas touché (D6).
# L'étape des comptes est déclarée ici et non dans module_configure : le runner
# lance chaque fonction dans son propre sous-shell (D4) ; pas sur un
# changement de langue, les comptes sont déjà dans le profil.
module_install() {
  local wanted installed="" reinstall=0 url
  wanted=$(_thunderbird_wanted_lang)
  if [[ -x $THUNDERBIRD_DIR/thunderbird ]]; then
    installed=$(_thunderbird_installed_lang "$THUNDERBIRD_DIR")
    if [[ $installed == "$wanted" ]]; then
      log_ok "Thunderbird déjà installé ($installed) : $THUNDERBIRD_DIR"
      return 0
    fi
    log_info "Thunderbird installé en « ${installed:-langue illisible} », Ubuntu en « $wanted » : réinstallation (profil conservé)."
    reinstall=1
  fi
  url=${THUNDERBIRD_URL//@LANG@/$wanted}
  local parent archive tmpdir stale
  parent=$(dirname -- "$THUNDERBIRD_DIR")
  mkdir -p -- "$parent" || return 1
  # Dossier temporaire laissé par une extraction interrompue sans nettoyage
  # (processus tué, coupure de courant) : ≈ 300 Mio que rien d'autre ne retire.
  for stale in "$parent"/.thunderbird.??????; do
    [[ -d $stale ]] || continue
    run rm -rf -- "$stale" || return 1
    log_info "Extraction interrompue retirée : $stale"
  done
  archive=$(mktemp -t thunderbird.XXXXXX.tar.xz) || return 1
  add_cleanup "rm -f '$archive'"
  ui_spin "Téléchargement de Thunderbird (archive de Mozilla)" \
    run curl -fsSL --retry 2 "$url" -o "$archive" \
    || { log_error "Téléchargement de Thunderbird impossible : $url"; return 1; }
  tmpdir=$(mktemp -d -- "$parent/.thunderbird.XXXXXX") || return 1
  add_cleanup "rm -rf '$tmpdir'"
  ui_spin "Extraction de Thunderbird" run tar -xJf "$archive" -C "$tmpdir" \
    || { log_error "Extraction de l'archive de Thunderbird impossible : $url"; return 1; }
  [[ -x $tmpdir/thunderbird/thunderbird ]] \
    || { log_error "Archive de Thunderbird sans thunderbird/thunderbird : $url"; return 1; }
  # Langue lue dans l'archive même : si elle n'est pas celle demandée (ou
  # illisible), module_check ne serait jamais satisfait et chaque relance
  # réinstallerait ; on échoue plutôt, en le nommant.
  installed=$(_thunderbird_installed_lang "$tmpdir/thunderbird")
  [[ $installed == "$wanted" ]] \
    || { log_error "Archive de Thunderbird en « ${installed:-langue illisible} » au lieu de « $wanted » : $url"; return 1; }
  if (( reinstall )); then
    run mv -T -- "$THUNDERBIRD_DIR" "$tmpdir/ancien" \
      || { log_error "Impossible de mettre de côté $THUNDERBIRD_DIR"; return 1; }
    if ! run mv -T -- "$tmpdir/thunderbird" "$THUNDERBIRD_DIR"; then
      run mv -T -- "$tmpdir/ancien" "$THUNDERBIRD_DIR"
      log_error "Impossible de placer Thunderbird dans $THUNDERBIRD_DIR (ancienne installation remise)"
      return 1
    fi
    log_ok "Thunderbird réinstallé en « $wanted » : $THUNDERBIRD_DIR"
    return 0
  fi
  run mv -T -- "$tmpdir/thunderbird" "$THUNDERBIRD_DIR" \
    || { log_error "Impossible de placer Thunderbird dans $THUNDERBIRD_DIR"; return 1; }
  log_ok "Thunderbird installé ($wanted) : $THUNDERBIRD_DIR"
  manual_step "$THUNDERBIRD_ACCOUNTS_MANUAL"
}

# Commande, lanceur et stratégie des dictionnaires, sans réseau : c'est ce qui
# rétablit un lanceur retiré sans retélécharger Thunderbird (D4). Le lanceur est
# un fichier (pas un lien), réécrit seulement s'il diffère du gabarit rendu (D3).
# La stratégie est copiée dans /etc (D7) ; Thunderbird installe les dictionnaires
# au démarrage suivant.
module_configure() {
  install_system_file "$THUNDERBIRD_POLICIES_SRC" "$THUNDERBIRD_POLICIES" || return 1
  mkdir -p -- "$(dirname -- "$THUNDERBIRD_BIN")" "$THUNDERBIRD_APPS_DIR" || return 1
  if [[ $(readlink -- "$THUNDERBIRD_BIN") != "$THUNDERBIRD_DIR/thunderbird" ]]; then
    run ln -sfn -- "$THUNDERBIRD_DIR/thunderbird" "$THUNDERBIRD_BIN" || return 1
    log_ok "Commande thunderbird : $THUNDERBIRD_BIN"
  fi
  if ! cmp -s -- <(_thunderbird_desktop) "$THUNDERBIRD_DESKTOP"; then
    _thunderbird_desktop >"$THUNDERBIRD_DESKTOP" || return 1
    log_ok "Lanceur Thunderbird : $THUNDERBIRD_DESKTOP"
    # Pour les MimeType (mailto:) ; absent, le menu trouve quand même le lanceur.
    if command -v update-desktop-database >/dev/null 2>&1; then
      run update-desktop-database "$THUNDERBIRD_APPS_DIR" \
        || log_warn "update-desktop-database a échoué : sans effet sur le lanceur."
    fi
  fi
  return 0
}
