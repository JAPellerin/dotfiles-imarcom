## Why

Le poste n'a pas d'émulateur de terminal choisi : sur Ubuntu, c'est GNOME Terminal par défaut. Le module installe **Ghostty**, sa configuration versionnée et la police **MesloLGS NF** dont Powerlevel10k a besoin pour afficher ses icônes et ses séparateurs — sans elle, le prompt déjà installé par le module `shell` s'affiche avec des carrés vides.

C'est aussi le **premier vrai client d'`install_font`**, le helper posé par la vague 0 : aucune police Nerd n'existe dans les dépôts d'Ubuntu, et c'est précisément le cas pour lequel le helper a été écrit.

Relevé le 22 sept 2026 sur Ubuntu 26.04.1 : **Ghostty 1.3.0 est dans les dépôts Ubuntu** (`ghostty`, dépendances GTK4 et libadwaita), donc aucun dépôt tiers ni `.deb` téléchargé. Le paquet livre `/usr/bin/ghostty` et `com.mitchellh.ghostty.desktop` (`Categories=System;TerminalEmulator;`), mais **n'enregistre aucune alternative `x-terminal-emulator`** : le module doit s'en charger pour que Ghostty devienne le terminal par défaut.

## What Changes

- **Module `terminal`** (`modules/21-terminal.sh`, groupe `shell`, dépend de `base` et `shell`, `MODULE_NEEDS_GUI=1`) :
  - `apt_install ghostty` depuis les dépôts Ubuntu ;
  - **police MesloLGS NF** par `install_font`, depuis les quatre fichiers publiés par Powerlevel10k (`romkatv/powerlevel10k-media`) — ceux que son assistant installe lui-même, famille `MesloLGS NF`, ~10 Mio au total ;
  - **configuration versionnée** `config/terminal/ghostty` liée vers `~/.config/ghostty/config` par `link_config` : police et taille, et le minimum vérifiable ;
  - **terminal par défaut** : enregistrement puis sélection de l'alternative Debian `x-terminal-emulator`, et réglage GNOME quand son schéma est présent ; vérifié après coup.
- **`install_font` accepte une URL de fichier de police**, pas seulement une archive : appelé avec une URL qui se termine par `.ttf` ou `.otf`, le helper installe ce fichier tel quel. Plusieurs URL peuvent être données pour une même famille. Le comportement « archive `.zip` » est inchangé.

Hors périmètre, assumé explicitement :

- **Thème de Ghostty** — la configuration versionnée ne fixe que la police et sa taille. Ghostty embarque une liste de thèmes qu'on ne peut consulter qu'une fois installé (`ghostty +list-themes`) ; en nommer un au jugé serait une valeur inventée. À ajouter après le passage en VM.
- **Raccourcis clavier, transparence, onglets** — réglages de confort à poser au fil de l'usage dans le fichier versionné, pas à deviner maintenant.
- **Autres formats d'archive** (`.tar.xz`, `.tar.gz`) pour `install_font` — les quatre fichiers de p10k rendent le cas inutile ici ; à ajouter quand une police le demandera.
- **Autres polices** — une seule famille suffit au prompt et au terminal.
- **Intégration shell de Ghostty** (`shell-integration`) — activée par défaut par Ghostty pour zsh ; rien à configurer.
- **GNOME Terminal** — laissé installé. Le retirer relève du module `gnome`.

## Capabilities

### New Capabilities
- `module-terminal` : le module `terminal` — Ghostty depuis les dépôts Ubuntu, police MesloLGS NF, configuration versionnée, terminal par défaut du bureau.

### Modified Capabilities
- `module-contract` : l'exigence « Installation d'une police depuis une archive » évolue — le helper accepte aussi une ou plusieurs URL de fichiers de police (`.ttf`, `.otf`), en plus d'une archive `.zip`.

## Impact

- Nouveaux `modules/21-terminal.sh`, `config/terminal/ghostty`, `tests/test-terminal.sh` ; `lib/fonts.sh` étendu (+ cas dans `tests/test-fonts.sh`).
- Fichiers créés hors dépôt : `~/.local/share/fonts/MesloLGSNF/` (quatre `.ttf`), `~/.config/ghostty/config` (lien vers le dépôt).
- Écriture système : `update-alternatives` pour `x-terminal-emulator` (avec `sudo`), que le paquet Ghostty n'enregistre pas lui-même.
- Réseau : quatre téléchargements depuis `github.com/romkatv/powerlevel10k-media` (~10 Mio). Les tests restent hors ligne (URL `file://`).
- **Module graphique** (`MODULE_NEEDS_GUI=1`) : sauté dans la WSL, comme `navigateur`. Les tests hors ligne y tournent, mais la validation réelle se fait **en VM** — y compris le mécanisme du terminal par défaut, qu'aucune mesure hors GNOME ne peut trancher.
- Docs : `ROADMAP.md` (`terminal` fait), `CLAUDE.md` (le helper de police accepte des fichiers).
