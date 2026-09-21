# config/navigateur

Fichiers déployés par `modules/25-navigateur.sh` (copies dans `/etc` via `install_system_file`, jamais des liens).

| Fichier | Cible | Rôle |
|---|---|---|
| `chromium-1password.json` | `/etc/brave/policies/managed/1password.json`, `/etc/opt/chrome/policies/managed/1password.json` | Stratégie d'entreprise Chromium : extension 1Password (`aeblfdkhhhdcdjpifhhbdiojplfjncoa`, Chrome Web Store) installée en `normal_installed` (activée, désactivable) et épinglée à la barre d'outils (`toolbar_pin`). Doc : https://chromeenterprise.google/policies/#ExtensionSettings |
| `firefox-policies.json` | `/etc/firefox/policies/policies.json` | Idem pour Firefox (`{d634138d-c276-4fc8-924b-40a0ea21d284}`, addons.mozilla.org), bouton placé dans la barre de navigation (`default_area`) ; le module y ajoute `Preferences.intl.locale.requested` quand `firefox-l10n-fr` est installé. Doc : https://mozilla.github.io/policy-templates/ |
| `mozilla.pref` | `/etc/apt/preferences.d/mozilla` | Épinglage demandé par Mozilla : priorité 1000 pour que son `firefox` supplante le paquet de transition d'Ubuntu (snap), déclassement d'époque compris. Doc : https://support.mozilla.org/kb/install-firefox-linux |
| `google-chrome.default` | `/etc/default/google-chrome` | Empêche le paquet `google-chrome-stable` d'ajouter son propre dépôt (`.list`) : le dépôt est géré en deb822 par le module. Doc : https://www.google.com/linuxrepositories/ |
| `bip39-english.txt` | — (lu par le module) | Liste officielle BIP-0039 (2048 mots, https://github.com/bitcoin/bips/blob/master/bip-0039/english.txt, SHA-256 `2f5eed53a4727b4bf8880d8f3f199efc90e58503646d9ff8eff3a2ed3b24dbda`) pour calculer le 25ᵉ mot du code Brave Sync. |
