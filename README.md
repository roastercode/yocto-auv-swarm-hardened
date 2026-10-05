# yocto-auv-swarm-hardened

Système d'exploitation durci pour un nuage de drones sous-marins : essaim d'AUV,
passerelle semi-submersible, véhicule de surface (USV), liaison satellite/cloud.

Statut : conception. Le build démarrera une fois la base
[yocto-jetson-tegra-hardened](https://github.com/roastercode/yocto-jetson-tegra-hardened)
finalisée.

## Relation avec yocto-jetson-tegra-hardened

Dépôt séparé, projet distinct, même socle. La base n'est pas copiée : elle est
consommée comme dépendance de couche, à version épinglée. Les correctifs du socle
(durcissement, outils d'analyse noyau, suivi CVE) se font dans la base et
descendent ici par simple mise à jour de l'épinglage.

## Architecture

~~~text
              CENTRE / CLOUD
                    |
          SAT / 4G-5G / Internet
                    |
                  USV           GNSS, passerelle, coordination flotte
                    |
                RF / Wi-Fi
                    |
            SEMI-SUBMERSIBLE    mât RF/SAT hors de l'eau, edge compute,
                    |           USBL, passerelle DTN
          +---------+---------+
          |                   |
       OPTIQUE           ACOUSTIQUE
     (rendez-vous)      (longue portée)
          |                   |
     AUV proches         AUV éloignés
          \                   /
           +--- essaim AUV --+
~~~

Trois niveaux :

- **Centre** : planification globale, cartes, historique, supervision.
- **Edge maritime** (USV, semi-sub) : relais, stockage, fusion, replanification,
  référence de navigation GNSS vers USBL.
- **Edge immergé** (AUV) : chaque AUV est autonome ; plusieurs AUV forment un
  micro-nuage temporaire.

## Configurations d'emploi

La discrétion n'est pas une propriété du système, c'est un mode (EMCON).

| Configuration | Surface | Canaux | Discrétion |
|---|---|---|---|
| Ouverte | USV | acoustique, optique, RF, SAT | faible |
| Discrète | semi-sub profil bas | optique, émissions acoustiques LPI | moyenne |
| Autonome silencieuse | aucune | optique en rendez-vous, remontée exceptionnelle | élevée |

Mode silencieux : optique seule en immersion, regroupements réguliers à portée
optique, remontée (fix GNSS, rafale SAT ou radio courte portée) uniquement si la
perte de liaison avec le groupe dépasse un seuil.

## Communications

- **Acoustique** : longue portée, débit de l'ordre de la centaine de bit/s au kbit/s,
  environ 0,67 s de propagation par km. Interopérabilité visée : JANUS (STANAG 4748).
- **Optique** : quelques dizaines de mètres, débit élevé, pointage requis.
  Lien de rendez-vous, pas lien permanent.
- **RF / SAT** : uniquement depuis la surface ou un mât.
- **DTN** : Bundle Protocol v7 (RFC 9171) pour le stockage et la retransmission
  entre véhicules, avec priorités et durée de validité par message.
- **ROS 2 / Zenoh** : interne à chaque véhicule et sur les liens larges uniquement.
  Jamais sur le lien acoustique.

## Navigation

- Inertiel + DVL en mode ouvert ; inertiel pur en silence (dérive nettement plus forte).
- Recalage par USBL depuis une plateforme GNSS (USV ou semi-sub).
- Sans surface : options passives par corrélation gravimétrique ou magnétique.
- Horloge locale stable (type CSAC) pour la synchronisation et le ranging acoustique.

## Socle OS

- Yocto durci (base yocto-jetson-tegra-hardened), noyau PREEMPT_RT.
- MCU de sûreté séparé (Zephyr) : propulsion, ballast, largage de lest, watchdog.
- **EMCON appliqué par le noyau** : politique obligatoire (LSM) qui interdit l'accès
  aux pilotes d'émission selon le niveau courant ; changement de niveau réservé à
  une entité de confiance (mission signée ou ordre authentifié) ; transitions journalisées.
- Magasin DTN persistant résistant aux coupures d'alimentation.

## Chantiers ouverts

- **Communication optique** : amélioration à mener, les modems optiques couvrant des
  niveaux de qualité très différents (LED ou laser, PIN/APD/PMT, longueur d'onde
  bleu ou vert selon l'eau, modulation et codage correcteur). Piste : acquisition
  LED large faisceau puis transfert laser pointé.
- **Rendez-vous sous dérive inertielle** : portée optique contre incertitude de position.
- **Authentification sur trames acoustiques courtes** : une signature Ed25519 (64 octets)
  dépasse souvent la charge utile ; anti-rejeu sans horloge fiable.
- **Discrétion** : signature du mât, des émissions et de la propulsion.

## Version

Voir `VERSION` et `CHANGELOG.md`.
