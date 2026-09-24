#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/62-thunderbird.sh — Thunderbird depuis l'archive officielle de Mozilla,
# en français, installé dans le dossier personnel (méthode « dossier personnel »).
#   https://support.mozilla.org/kb/installing-thunderbird-linux
#
# Sur Ubuntu 26.04, le paquet `thunderbird` n'est qu'une transition vers le snap,
# et le dépôt apt de Mozilla ne publie pas Thunderbird : l'archive .tar.xz est le
# seul format officiel. Installée dans ~/.local/share, elle appartient à
# l'utilisateur et la mise à jour intégrée de Thunderbird peut y écrire (D2) ;
# aucun sudo. Commande dans ~/.local/bin (d'où la dépendance à `shell`, D4b),
# lanceur rendu depuis le fichier .desktop de Mozilla (D3).
# Voir openspec/changes/thunderbird/design.md.
MODULE_NAME="thunderbird"
MODULE_DESC="Thunderbird (archive officielle de Mozilla dans le dossier personnel)"
MODULE_GROUP="apps"
MODULE_DEPS="base shell"
MODULE_NEEDS_GUI=1

# Mozilla redirige vers la dernière version publiée (D1) ; surchargeable (tests).
THUNDERBIRD_URL="${THUNDERBIRD_URL:-https://download.mozilla.org/?product=thunderbird-latest&os=linux64&lang=fr}"
THUNDERBIRD_DIR="$HOME/.local/share/thunderbird"
THUNDERBIRD_BIN="$HOME/.local/bin/thunderbird"
THUNDERBIRD_APPS_DIR="$HOME/.local/share/applications"
THUNDERBIRD_DESKTOP="$THUNDERBIRD_APPS_DIR/thunderbird.desktop"
THUNDERBIRD_DESKTOP_SRC="config/thunderbird/thunderbird.desktop"
THUNDERBIRD_ACCOUNTS_MANUAL="Ouvrir Thunderbird (menu des applications) et ajouter les comptes de courriel et les agendas Google."

# _thunderbird_desktop : le gabarit rendu sur stdout, @THUNDERBIRD_DIR@ remplacé
# par le chemin absolu d'installation (remplacement entre guillemets : un « & »
# dans le chemin reste littéral).
_thunderbird_desktop() {
  local tpl
  tpl=$(<"$DOTFILES_DIR/$THUNDERBIRD_DESKTOP_SRC") || return 1
  printf '%s\n' "${tpl//@THUNDERBIRD_DIR@/"$THUNDERBIRD_DIR"}"
}

# Déjà fait = binaire exécutable dans le dossier d'installation, commande liée à
# ce binaire, lanceur identique au gabarit rendu (D4). Ni la version ni la langue
# ne sont vérifiées : Thunderbird se met à jour lui-même.
module_check() {
  [[ -x $THUNDERBIRD_DIR/thunderbird ]] || return 1
  [[ -L $THUNDERBIRD_BIN && $(readlink -- "$THUNDERBIRD_BIN") == "$THUNDERBIRD_DIR/thunderbird" ]] || return 1
  # cmp rend 2 si le lanceur manque : ramené à 1, seul code « à faire » du contrat.
  cmp -s -- <(_thunderbird_desktop) "$THUNDERBIRD_DESKTOP" || return 1
}

# Archive téléchargée puis extraite dans un dossier temporaire du même système
# de fichiers que la destination, renommé seulement s'il contient
# thunderbird/thunderbird : jamais de dossier d'installation à moitié écrit (D1).
# L'étape des comptes est déclarée ici et non dans module_configure : le runner
# lance chaque fonction dans son propre sous-shell (D4).
module_install() {
  if [[ -x $THUNDERBIRD_DIR/thunderbird ]]; then
    log_ok "Thunderbird déjà installé : $THUNDERBIRD_DIR"
    return 0
  fi
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
    run curl -fsSL --retry 2 "$THUNDERBIRD_URL" -o "$archive" \
    || { log_error "Téléchargement de Thunderbird impossible : $THUNDERBIRD_URL"; return 1; }
  tmpdir=$(mktemp -d -- "$parent/.thunderbird.XXXXXX") || return 1
  add_cleanup "rm -rf '$tmpdir'"
  ui_spin "Extraction de Thunderbird" run tar -xJf "$archive" -C "$tmpdir" \
    || { log_error "Extraction de l'archive de Thunderbird impossible : $THUNDERBIRD_URL"; return 1; }
  [[ -x $tmpdir/thunderbird/thunderbird ]] \
    || { log_error "Archive de Thunderbird sans thunderbird/thunderbird : $THUNDERBIRD_URL"; return 1; }
  run mv -T -- "$tmpdir/thunderbird" "$THUNDERBIRD_DIR" \
    || { log_error "Impossible de placer Thunderbird dans $THUNDERBIRD_DIR"; return 1; }
  log_ok "Thunderbird installé : $THUNDERBIRD_DIR"
  manual_step "$THUNDERBIRD_ACCOUNTS_MANUAL"
}

# Commande et lanceur, sans réseau : c'est ce qui rétablit un lanceur retiré sans
# retélécharger Thunderbird (D4). Le lanceur est un fichier (pas un lien), réécrit
# seulement s'il diffère du gabarit rendu (D3).
module_configure() {
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
