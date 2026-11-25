# TP3 – Jenkins ⇆ Docker (Build → Test → Push → Deploy)

**Module :** Introduction au DevOps – ISG de Sousse (3ᵉ LIG)

## Liens

- **Projet GitHub :** https://github.com/mohamedsedkibk/tp3-jenkins-docker
- **Image sur Docker Hub :** https://hub.docker.com/r/mohamedsedkiboukadida/monapp

## Objectif

Conteneuriser l'application web statique du TP précédent (`index.html`, `style.css`) avec **Nginx**, puis automatiser avec **Jenkins** :

1. construction de l'image Docker ;
2. test « smoke » (le conteneur répond bien `200 OK`) ;
3. publication de l'image sur **Docker Hub** ;
4. déploiement avec **docker compose**.

## Structure du dépôt

```
tp3-jenkins-docker/
├── index.html           # page web (TP précédent)
├── style.css            # feuille de style (TP précédent)
├── Dockerfile           # image Nginx contenant le site
├── Jenkinsfile          # pipeline Build → Test → Push → Deploy
├── docker-compose.yml   # déploiement (staging)
└── README.md
```

(`Jenkinsfile2` est un ancien pipeline du TP précédent, non utilisé ici.)

---

## 1. Prérequis : Docker sur le nœud Jenkins

- Machine : Windows, avec **Docker Desktop** et **Jenkins** installé comme service Windows (port 9090).
- Vérification :

```powershell
docker version
docker compose version
```

### Donner l'accès Docker à Jenkins

Le service Jenkins ne trouvait pas Docker au départ (erreur « 'docker' n'est pas reconnu »), car Docker Desktop est installé dans le profil de l'utilisateur. Solution utilisée :

*Manage Jenkins → System → Global properties → Environment variables* :

| Nom | Valeur |
|---|---|
| `PATH+DOCKER` | `C:\Users\<utilisateur>\AppData\Local\Programs\DockerDesktop\resources\bin` |

> L'énoncé conseille d'exécuter le service Jenkins sous un compte utilisateur. Ici, le service tourne sous `NT AUTHORITY\SYSTEM` (résultat de `whoami`) ; Docker fonctionne quand même grâce à la variable `PATH+DOCKER`.

Vérification dans un pipeline Jenkins (job `TP3-Docker-Check`) :

```groovy
pipeline {
  agent any
  stages {
    stage('Docker') {
      steps {
        bat 'whoami'
        bat 'docker version'
        bat 'docker run --rm nginx:alpine nginx -v'
      }
    }
  }
}
```

## 2. Dockerfile

```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
COPY style.css /usr/share/nginx/html/style.css
EXPOSE 80
```

| Instruction | Rôle |
|---|---|
| `FROM nginx:alpine` | Image de base : serveur web Nginx, version légère Alpine |
| `COPY index.html ...` | Copie la page dans le dossier servi par Nginx |
| `COPY style.css ...` | Copie la feuille de style |
| `EXPOSE 80` | Port d'écoute de Nginx dans le conteneur |

Test local (facultatif) :

```bash
docker build -t monapp:dev .
docker run -d -p 8080:80 --name monappdev monapp:dev
# http://localhost:8080
```

## 3. Identifiants Jenkins

*Manage Jenkins → Credentials → System → Global credentials → Add Credentials* :

- Kind : *Username with password*
- Username : `mohamedsedkiboukadida`
- Password : Personal Access Token Docker Hub (droits **Read & Write**)
- ID : `dockerhub-cred`

> L'énoncé propose l'ID `dockerhub-creds` ; l'identifiant `dockerhub-cred` existait déjà (TP4), le Jenkinsfile l'utilise.

## 4. Jenkinsfile (Build → Test → Push → Deploy)

| Stage | Action |
|---|---|
| Checkout | `checkout scm` : récupère le dépôt GitHub du job |
| Docker Build | `docker version` puis `docker build -t mohamedsedkiboukadida/monapp:build-<n> .` |
| Smoke Test | Lance le conteneur `monapp_test` sur le port 8083, vérifie la réponse `200 OK` avec `curl -I`, puis supprime le conteneur. Le build échoue si la réponse n'est pas `200 OK`. |
| Push (Docker Hub) | `docker login` avec les identifiants Jenkins, tag `latest`, `docker push` des tags `build-<n>` et `latest` |
| Deploy (docker compose) | `docker-compose pull`, `docker-compose up -d`, `docker ps` |

Écarts par rapport à l'énoncé :

- **Port du smoke test : 8083** au lieu de 8081, car le port 8081 est déjà occupé sur la machine.
- **Test bloquant :** après `find "200 OK"`, `if errorlevel 1 (... exit /b 1)` fait échouer le stage si le site ne répond pas (sinon la dernière commande `docker rm` masquerait l'échec).
- **`echo %PASS%| docker login`** sans espace avant le `|`, sinon Windows ajoute un espace à la fin du mot de passe.
- **Stage Deploy ajouté** dans le pipeline. Sous Windows, le service Jenkins utilise `docker-compose.exe` (fourni par Docker Desktop), car le plugin `docker compose` n'est pas visible par le service.

Le job Jenkins `TP3-Jenkins-Docker` est de type *Pipeline script from SCM* (Git, branche `*/master`, Script Path `Jenkinsfile`).

## 5. Déploiement (staging) avec docker compose

`docker-compose.yml` :

```yaml
services:
  web:
    image: mohamedsedkiboukadida/monapp:latest
    ports:
      - "8080:80"
    restart: unless-stopped
```

Commandes :

```bash
docker compose pull
docker compose up -d
docker ps
# http://localhost:8080
```

## 6. Webhook GitHub

- Dans Jenkins : cocher **GitHub hook trigger for GITScm polling** dans le job.
- Dans GitHub : *Settings → Webhooks → Add webhook* avec l'URL `http://<adresse-publique-jenkins>/github-webhook/`.

> Ici Jenkins tourne sur `localhost:9090`, qui n'est pas joignable depuis GitHub. Pour que le webhook fonctionne, il faut exposer Jenkins sur Internet (par exemple avec un tunnel comme ngrok) et utiliser cette adresse publique dans GitHub.

## Commandes de base

```bash
docker version
docker build -t monapp:dev .
docker run -d -p 8080:80 --name monapp monapp:dev
docker ps
docker stop monapp && docker rm monapp
docker tag monapp:dev mohamedsedkiboukadida/monapp:latest
docker push mohamedsedkiboukadida/monapp:latest
```
