## Installer Murmur

1. Télécharger `Murmur.zip` ci-dessous, le décompresser et glisser `Murmur.app` dans **Applications**.
2. Dans le Terminal, une seule fois : `xattr -cr /Applications/Murmur.app`
   (l'app n'est pas signée par Apple ; sans cette commande, macOS refuse de l'ouvrir).
   À défaut : ouvrir l'app, puis Réglages Système > Confidentialité et sécurité > « Ouvrir quand même ».
3. Ouvrir Murmur et accorder le **micro** et l'**accessibilité**. Le modèle Parakeet se télécharge au premier lancement.

Ensuite, Murmur propose lui-même les nouvelles versions (Paramètres > Vérifier automatiquement les mises à jour) ; macOS peut redemander les autorisations après une mise à jour.

Pour la retouche par Claude, mettre sa propre clé API Anthropic dans les réglages. Ne pas installer en parallèle de VoiceInk : les deux apps partagent leurs réglages et leurs données.

Le code source de cette version est celui du commit indiqué par l'étiquette (licence GPLv3, dérivé de VoiceInk).
