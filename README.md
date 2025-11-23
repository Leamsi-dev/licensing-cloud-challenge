# Licensing Cloud Challenge
Système de gestion de licences cloud avec :
- Limitation du nombre d'applications par client
- Quota d'exécutions sur fenêtre glissante de 24h
- Validation JWT sécurisée
- Stockage PostgreSQL + Redis pour les quotas

#Choix Techno

- Python 3.11.9
- FastAPI
- PostgreSQL
- Redis
- JWT pour l'authentification
  
#Pourquoi ? car :

Haute performance, typage fort avec validation automatique des requêtes 
Développement rapide et sécurisé
Bonne gestion de la concurrence
Écosystème mature pour la sécurité et les APIs
Facilité de test et documentation automatique (OpenAPI)
L'architecture avec Redis pour la fenêtre glissante

## 🚀 Lancement

# Clonez le repository
# Dans ton dossier licensing-cloud/

###```bash
##mkdir -p keys(Facultatif)
##docker compose up --build

#Dans le repertoire test
scenario.postman.json

#doc Swagger ui
http://localhost:8000/docs

#doc ReDoc
http://localhost:8000/redoc

## Dans le terminal, pour le test automatique
chmod +x test_licensing_scenario.sh(facultatif)
./test_licensing_scenario.sh
