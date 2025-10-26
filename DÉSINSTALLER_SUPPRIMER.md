# `README.md` – Script de désactivation du routeur NAT Debian

## 🧭 Objectif

Ce script permet de **désactiver proprement** un routeur NAT configuré sur Debian, en annulant les modifications effectuées par le script de configuration (`config_routeur.sh`).  
Il propose un **menu interactif**, une **gestion fine des erreurs**, des **affichages colorés**, et une **sécurité renforcée**.

---

## 🧱 Structure du script

### 1. **En-tête et sécurité**

```bash
set -euo pipefail
```

- `-e` : stoppe le script si une commande échoue
- `-u` : stoppe si une variable non définie est utilisée
- `-o pipefail` : stoppe si une commande dans un pipe échoue

> 🔐 Cela garantit que le script ne continue pas en cas d’erreur silencieuse.

---

### 2. **Affichage coloré et fonctions utilitaires**

```bash
print_success "..."   # ✅ Affiche un message en vert
print_error "..."     # ❌ Affiche un message en rouge
print_warning "..."   # ⚠️ Affiche un message en jaune
print_info "..."      # ℹ️ Affiche un message d'information
```

> 🎨 Ces fonctions rendent le script plus lisible et agréable à utiliser, surtout pour les débutants.

---

### 3. **Vérification des droits root**

```bash
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en root"
   exit 1
fi
```

> ✅ Évite les erreurs dues à un manque de privilèges.

---

### 4. **Fonctions de sécurité**

#### 🔒 `backup_file /etc/sysctl.conf`

Crée une sauvegarde horodatée du fichier avant modification.

#### 🔎 `validate_interface enp1s0`

Vérifie que l’interface réseau existe, sinon affiche les interfaces disponibles.

---

## 📋 Menu interactif

L’utilisateur choisit une action parmi :

| Option | Action |
|--------|--------|
| 1 | Supprimer les règles NAT (`iptables`) |
| 2 | Arrêter le serveur DHCP |
| 3 | Supprimer l’IP statique de l’interface LAN |
| 4 | Désactiver le routage IP |
| 5 | Tout désactiver (1 à 4) |
| 6 | Tout désactiver + désinstaller les paquets |

> 🛑 L’option 6 demande une **confirmation explicite** avant exécution.

---

## 🔧 Détail des actions

### ✅ Action 1 : Suppression des règles NAT

- Vide les règles `iptables` (NAT et FORWARD)
- Sauvegarde l’état vide si `netfilter-persistent` est installé

### ✅ Action 2 : Arrêt du serveur DHCP

- Stoppe et désactive `isc-dhcp-server` si actif

### ✅ Action 3 : Désactivation de l’IP statique

- Supprime toutes les IP de l’interface LAN

### ✅ Action 4 : Désactivation du routage IP

- Désactive immédiatement (`sysctl`)
- Modifie `/etc/sysctl.conf` pour rendre le changement persistant

### ✅ Action 6 : Nettoyage complet

- Supprime les paquets : `isc-dhcp-server`, `iptables-persistent`, `netfilter-persistent`
- Utilise `apt purge` et `autoremove` pour un nettoyage propre

---

## 🧪 Conseils après exécution

- Pour redémarrer les interfaces réseau :
  ```bash
  sudo systemctl restart networking
  ```
- Pour redémarrer complètement :
  ```bash
  sudo reboot
  ```

---

## 🤝 Contribution

Auteurs :
- **SMK** - Développeur principal
- **GitHub Copilot** - Assistance au développement
- **Google Gemini** - Revue et optimisation
- **Claude (Anthropic)** - Optimisation finale

## 📄 Licence

Ce projet est sous licence **MIT**.

```
MIT License

Copyright (c) 2025 smk & Copilot & Gemini & Claude

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 🔗 Ressources utiles

- [Documentation Debian - Routage](https://wiki.debian.org/NetworkConfiguration)
- [Guide iptables](https://netfilter.org/documentation/)
- [Documentation isc-dhcp-server](https://www.isc.org/dhcp/)

## 📞 Support

Pour toute question ou problème :
- Ouvrir une issue sur le dépôt GitHub
- Consulter la section Dépannage ci-dessus
- Vérifier les logs système : `journalctl -xe`

---

**Note** : Ce script a été testé sur Debian 11/12 et Ubuntu 20.04/22.04. Testez toujours sur un environnement non-production avant déploiement.

**Version** : 1.0.0 | **Date** : 26 octobre 2025
