## Context

Voir `proposal.md`. Le socle fournit `apt_install`, `pkg_installed`, `link_config` / `config_linked`, `install_font` / `font_installed` (`lib/fonts.sh`, vague 0), `manual_step`, `run`, `run_sudo`, `ui_spin`, `has_gui`.

Mesures du 22 sept 2026, faites sur les fichiers réels et non supposées :

| Fait | Mesure |
|---|---|
| `ghostty` dans les dépôts Ubuntu 26.04 | 1.3.0, dépend de GTK4 et libadwaita |
| Contenu du paquet | `/usr/bin/ghostty`, `com.mitchellh.ghostty.desktop` (`Categories=System;TerminalEmulator;`) |
| Scripts du paquet | `control` et `md5sums` seulement — **aucune alternative `x-terminal-emulator` enregistrée** |
| `Meslo.zip` des Nerd Fonts | **111 Mio**, 74 fichiers, 212 Mio décompressés ; famille « MesloLGS **Nerd Font** » |
| Fichiers de Powerlevel10k | 4 `.ttf`, ~2,5 Mio chacun ; famille « MesloLGS **NF** » |
| Polices Nerd dans les dépôts Ubuntu | aucune |
| Appelants actuels d'`install_font` | aucun module — seulement `tests/test-fonts.sh` |

## Goals / Non-Goals

**Goals :** un terminal installé, configuré et par défaut ; une police posée par le helper prévu pour ça ; un `module_check` qui constate l'état réel (famille connue de fontconfig, pas présence de fichiers).

**Non-Goals :** choisir un thème ; régler les raccourcis de Ghostty ; retirer GNOME Terminal ; gérer d'autres formats d'archive.

## Decisions

### D1. Police : les quatre fichiers de Powerlevel10k, pas l'archive Nerd Fonts
`https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20{Regular,Bold,Italic,Bold%20Italic}.ttf` — les fichiers que l'assistant `p10k configure` installe lui-même, et dont la famille est exactement `MesloLGS NF`, celle que documente Powerlevel10k. **~10 Mio au total.**
Alternative rejetée (mesurée) : `Meslo.zip` des Nerd Fonts, **111 Mio** pour 74 fichiers dont on ne garderait que 4, et une famille différente (« MesloLGS Nerd Font ») — ce qui obligerait en plus à filtrer l'archive, puisque le helper copie tous les `.ttf` qu'il trouve. Le `.tar.xz` (5 Mio) résout le volume mais pas la famille, et demanderait un format de plus.
Conséquence : le nom de famille exact `MesloLGS NF` est une constante du module, comparée **exactement** par `font_installed` depuis la contre-vérification du 22 sept 2026.

### D2. `install_font` accepte des fichiers, et change de signature
Nouvelle signature : `install_font <famille> <dossier> <url...>`. Chaque URL est traitée selon son extension — `.zip` extraite comme aujourd'hui, `.ttf` ou `.otf` installée telle quelle. Le variadique en dernier est la seule position naturelle pour un nombre libre d'URL.
Coût assumé : les neuf appels de `tests/test-fonts.sh` sont à réécrire. C'est mécanique, et **aucun module n'appelle encore le helper** (vérifié) — la fenêtre pour corriger la signature sans dette est maintenant.
`<dossier>` devient obligatoire plutôt que déduit de la famille : avec plusieurs URL, deviner un nom de dossier à partir d'une famille qui contient des espaces apportait plus de surprise que de confort.
Nom du fichier installé : le nom de base de l'URL, décodé (`MesloLGS%20NF%20Regular.ttf` → `MesloLGS NF Regular.ttf`) pour rester lisible dans `~/.local/share/fonts`. Le nom n'a aucune importance fonctionnelle — `fontconfig` lit la famille dans la table de noms du fichier, pas dans son nom — mais un dossier lisible se relit.
Inchangé : garde sur `font_installed`, téléchargement dans un temporaire, copie finale seulement en cas de succès, `fc-cache`, re-vérification de la famille, aucun dossier incomplet laissé.

### D3. Configuration versionnée minimale
`config/terminal/ghostty` → `~/.config/ghostty/config` par `link_config` (sauvegarde `.bak` d'un fichier existant, comportement du helper). Contenu :
```
font-family = MesloLGS NF
font-size = 11
```
Rien d'autre. **Aucun thème n'est fixé** : Ghostty embarque une liste de thèmes qu'on ne peut lire qu'une fois installé (`ghostty +list-themes`), et en nommer un au jugé serait inventer une valeur — le genre d'erreur que le passage en VM a déjà corrigé trois fois sur `navigateur`. Le fichier est versionné et lié : ajouter un thème après coup est une ligne, sans toucher au module.

### D4. Terminal par défaut : l'alternative Debian, plus GNOME si son schéma est là
Le paquet n'enregistre rien (mesuré), donc le module fait les deux gestes :
1. `run_sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/ghostty 50` puis `--set` — réenregistrer le même chemin est sans effet, donc idempotent ; l'état se lit par `update-alternatives --query x-terminal-emulator` (champ `Value:`).
2. `gsettings set org.gnome.desktop.default-applications.terminal exec /usr/bin/ghostty`, **seulement si le schéma existe** (`gsettings list-schemas`), pour ne pas échouer hors GNOME ; relu par `gsettings get`.
Vérification après coup, et `manual_step` si aucun des deux ne peut être constaté — le module ne se déclare pas fait sur un geste non vérifié.
**Incertitude assumée** : quel mécanisme Ubuntu 26.04 honore réellement pour `Ctrl+Alt+T` et « Ouvrir dans un terminal » ne se tranche pas hors d'une session GNOME. Les deux gestes ci-dessus sont les candidats standard ; la tâche de VM établit lequel agit, et corrige ce D4 en conséquence. Une troisième voie existe (`~/.config/xdg-terminals.list`, spécification XDG récente) : elle n'est **pas** implémentée d'avance, elle sera ajoutée si et seulement si la VM montre que les deux premières ne suffisent pas.

### D5. Dépendance à `base` et `shell`
`MODULE_DEPS="base shell"`, pour la raison que la contre-vérification de `cli-tools` a rendue visible : un module doit pouvoir être lancé seul et produire son effet. La police n'a d'utilité qu'avec le prompt Powerlevel10k que `shell` installe, et la configuration de Ghostty la désigne. Sans `shell`, `./setup.sh terminal` installerait une police que rien n'utilise.

### D6. `module_check`
Vrai si : `pkg_installed ghostty` **et** `font_installed "MesloLGS NF"` **et** `config_linked config/terminal/ghostty "$HOME/.config/ghostty/config"` **et** l'alternative `x-terminal-emulator` désigne `/usr/bin/ghostty`. La police est constatée par `fontconfig`, jamais par la présence de fichiers : c'est fontconfig qui décide si une police est utilisable.

### D7. Tests
`tests/test-fonts.sh` : les neuf appels passent à la nouvelle signature, et deux cas s'ajoutent — installation depuis plusieurs URL de fichiers (servies en `file://`, `.ttf` fabriqués sur place), et échec nommant l'URL fautive quand l'une d'elles manque, sans dossier laissé.
`tests/test-terminal.sh` (nouveau) : `HOME` isolé, doublures `dpkg-query`, `run_sudo` (compte les `apt-get` et les `update-alternatives`), `fc-list`/`fc-cache` comme dans `tests/test-fonts.sh`, `gsettings` doublé (schéma présent ou non). Cas : première application, réexécution, police déjà connue, schéma GNOME absent (l'alternative seule suffit à constater), aucun des deux gestes constatable → étape manuelle déclarée, `module_check` sur chacune de ses quatre conditions.
Aucune installation réelle, aucun réseau. **Le module est `NEEDS_GUI` : la WSL le saute**, seuls ces tests hors ligne y tournent.

## Risks / Trade-offs

- [Le mécanisme du terminal par défaut est incertain hors GNOME] → deux gestes standard appliqués et vérifiés, étape manuelle si aucun ne se constate, et la VM tranche (D4). Le module ne ment jamais sur son état.
- [Changer la signature d'`install_font` casserait des appelants] → il n'y en a aucun hors de ses tests (vérifié) ; la fenêtre est maintenant, elle se referme dès qu'un second module l'appelle.
- [`update-alternatives --install` fait le travail du paquet] → c'est l'usage prévu du mécanisme, et le lien est retiré proprement par `--remove` si Ghostty était désinstallé. Le risque réel serait un futur paquet Ghostty enregistrant lui-même son alternative : le `--install` deviendrait redondant, sans dommage.
- [La police installée pour l'utilisateur seul n'est pas vue par l'écran de connexion ou un autre compte] → recherché : une police par utilisateur suffit, et `/usr/local/share/fonts` demanderait `sudo` pour un confort personnel.
- [`font-size = 11` ne conviendra pas à tous les écrans] → valeur de départ dans un fichier versionné et lié ; la corriger est une ligne.

## Migration Plan

Aucune migration : rien de tout cela n'existe sur le poste. Retour arrière = `apt remove ghostty`, `update-alternatives --remove x-terminal-emulator /usr/bin/ghostty`, suppression du dossier de police et du lien de configuration.
