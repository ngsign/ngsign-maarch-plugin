# Build the NGSign Maarch POC application image

The application image is built from `maarch/maarchcourrier:2301.1.5`. It adds:

- the native NGSign PHP connector;
- the three Option-B Maarch dispatch patches;
- the NGSign retrieval cron, every five minutes;
- a pre-built Angular SPA containing `app-ngsign`.

## 1. Provide the compiled SPA

The Maarch runtime image has no Node/Angular build toolchain. Follow
[`../../docs/OPTION_B_FRONTEND_TEST.md`](../../docs/OPTION_B_FRONTEND_TEST.md), then copy
the resulting **contents** of `dist/` to `poc/app/dist/`. `index.html` must exist there.

```bash
cp -a /path/to/MaarchCourrier/dist/. poc/app/dist/
```

Do not commit the generated `dist/` files: they are build artifacts. The Docker build
deliberately stops if `poc/app/dist/index.html` is absent.

## 2. Build and test locally

Run from the repository root:

```bash
docker build -f poc/app/Dockerfile -t ngsign/maarch-poc-app:dev .
cd poc
docker compose up -d
```

For the compose test, temporarily set `app.image` to `ngsign/maarch-poc-app:dev`.

## 3. Publish a version

```bash
docker login
docker build -f poc/app/Dockerfile -t ngsign/maarch-poc-app:1.0.1 -t ngsign/maarch-poc-app:latest .
docker push ngsign/maarch-poc-app:1.0.1
docker push ngsign/maarch-poc-app:latest
```

Use the immutable `1.0.1` tag in `poc/docker-compose.yml` for a reproducible demo.

## Publication automatique avec GitHub Actions

Le workflow [`.github/workflows/publish-docker.yml`](../../.github/workflows/publish-docker.yml)
se déclenche après chaque merge sur `main` (un `push` sur `main`). Il compile le frontend
NGSign, construit l'image et la publie sur Docker Hub avec les tags `latest` et
`sha-<commit>`. Un tag Git `v1.0.2` publie aussi l'image Docker `1.0.2`.

Avant le premier lancement, créez dans **GitHub → Settings → Secrets and variables →
Actions** les secrets suivants :

- `DOCKERHUB_USERNAME` : le compte Docker Hub autorisé à publier `ngsign/maarch-poc-app` ;
- `DOCKERHUB_TOKEN` : un [access token Docker Hub](https://docs.docker.com/security/access-tokens/),
  avec l'autorisation d'écriture.

Le workflow utilise par défaut le dépôt `cedlerouge/MaarchCourrier`, branche `main`, pour
compiler la SPA. Pour verrouiller la même révision que votre image Maarch, créez les
variables GitHub `MAARCH_FRONTEND_REPOSITORY` et `MAARCH_FRONTEND_REF` (par exemple un
tag ou un commit 2301 compatible). Ces variables sont recommandées avant une publication
de production.

## Mise à jour du plugin et publication sur Docker Hub

### Cas 1 — paramètre de configuration : pas de publication d'image

Le fichier [`../remoteSignatoryBooks.xml`](../remoteSignatoryBooks.xml) est monté depuis
la machine hôte dans le conteneur. Pour modifier un paramètre qui s'y trouve (par
exemple `<url>`, `<token>`, `defaultMode` ou les coordonnées de signature), éditez ce
fichier puis redémarrez seulement l'application :

```bash
cd poc
docker compose restart app
```

Il ne faut ni reconstruire ni pousser l'image Docker dans ce cas. Ne placez jamais un
token réel dans une image publiée sur Docker Hub.

### Cas 2 — changement de code : reconstruire puis pousser l'image

Un changement dans `connector/`, `frontend/`, les patches Maarch, le cron ou le contenu
du frontend compilé fait partie de l'image. Après avoir modifié et testé le plugin,
construisez une **nouvelle version** depuis la racine du dépôt :

```bash
docker build -f poc/app/Dockerfile -t ngsign/maarch-poc-app:1.0.2 .
```

Connectez-vous au compte Docker Hub qui peut écrire dans le namespace `ngsign`, puis
publiez cette version :

```bash
docker login
docker push ngsign/maarch-poc-app:1.0.2
```

`docker build` crée l'image sur votre poste ; seul `docker push` l'envoie vers
`hub.docker.com/r/ngsign/maarch-poc-app`.

Vous pouvez aussi mettre à jour le tag pratique `latest`, en conservant impérativement
le tag versionné (`1.0.2`) :

```bash
docker tag ngsign/maarch-poc-app:1.0.2 ngsign/maarch-poc-app:latest
docker push ngsign/maarch-poc-app:latest
```

Enfin, pour utiliser la nouvelle version dans le POC, remplacez le tag de l'image `app`
dans `poc/docker-compose.yml`, puis :

```bash
cd poc
docker compose pull app
docker compose up -d --force-recreate app
```
