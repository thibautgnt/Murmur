<div align="center">
  <img src="VoiceInk/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="128" height="128" />
  <h1>Murmur</h1>
  <p>Dictée locale pour macOS : on parle, le texte arrive là où on écrit.</p>
</div>

---

## Ce que fait Murmur

- **Transcription 100 % locale** avec Parakeet TDT 0.6B v3, multilingue, français compris
- **Indicateur dans l'encoche**, façon Dynamic Island : point rouge, chrono, onde de la voix
- **Raccourci mixte** : appui court pour démarrer et arrêter, appui long pour parler
- **Dictionnaire personnel** : vocabulaire et remplacements de mots
- **Discret** : ni Dock ni barre des menus ; on l'ouvre en tapant son nom dans Spotlight
- **Ne coupe pas le son** des autres apps, et les sons de dictée ne sortent que par les haut-parleurs du Mac

## Installer et mettre à jour

Prérequis : macOS 15 ou plus, Xcode avec le composant Metal Toolchain
(`xcodebuild -downloadComponent MetalToolchain`).

```bash
make install
```

Compile, signe avec le certificat Apple Development personnel et installe `/Applications/Murmur.app`.
La signature stable évite de redonner les autorisations micro et accessibilité à chaque build.

## Licence

GPLv3, voir [LICENSE](LICENSE). Murmur est dérivé de [VoiceInk](https://github.com/Beingpax/VoiceInk) de Beingpax.
