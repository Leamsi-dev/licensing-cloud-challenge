# Licensing Cloud Challenge
Système de gestion de licences cloud avec :
- Limitation du nombre d'applications par client
- Quota d'exécutions sur fenêtre glissante de 24h
- Validation JWT sécurisée
- Stockage PostgreSQL + Redis pour les quotas

#Choix Techno
L'utilisation de Python 3.11.9 + FastAPI :

Développement rapide et sécurisé
Bonne gestion de la concurrence
Écosystème mature pour la sécurité et les APIs
Facilité de test et de documentation
L'architecture avec Redis pour la fenêtre glissante

## 🚀 Lancement

###```bash
##mkdir -p keys(Facultatif)
##docker compose up --build

# Licensing Cloud Challenge

Système de gestion de licences cloud avec limitation d'utilisation basée sur les droits attribués à chaque client.


## Technologies

- Python 3.11.9
- FastAPI
- PostgreSQL
- Redis
- JWT pour l'authentification

## Installation

# Dans ton dossier licensing-cloud/

Clonez le repository

## Dans le terminal, pour le test automatique
(chmod +x test_licensing_scenario.sh)
./test_licensing_scenario.sh
