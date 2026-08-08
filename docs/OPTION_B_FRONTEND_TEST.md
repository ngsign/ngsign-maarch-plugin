# Option B — reproducible frontend build & test

This is the **battle-tested** procedure to produce the Angular SPA that contains the
`ngsign` send dialog (Option B) and deploy it onto a running Maarch Courrier 2301
instance. It was executed end to end against Maarch **2301** (Angular 14).

The important constraint it works around: the `maarch/maarchcourrier` **runtime** Docker
image serves a pre-compiled `dist/` but ships **no `angular.json` and no Node/Angular
toolchain** → you cannot `ng build` inside it. So we **build outside**, then inject the
`dist/`.

> Tokens `<…>` as in `INSTALLATION.md`. Commands are host-side (macOS/Linux + Docker).

---

## 0. Match the Node version to your Maarch minor

The app-root `package.json` → `engines` decides the Node version:

| Maarch | Node | npm |
|---|---|---|
| **2301.1.x** | ≥ 18.7 | ≥ 8.15 |
| **2301.3.x** | ≥ 20.9 | ≥ 10.1 |

Below uses a `node:20` container (covers both). Building from the *exact* source of your
running backend avoids any version drift; if you build from a nearby 2301 minor, the SPA
stays API-compatible for this flow but prefer an exact match for production.

## 1. Get the frontend build sources (2301)

If you already have the Maarch source tree (with `angular.json` + `package.json` at the
root), skip this. Otherwise clone a 2301 source:

```bash
mkdir -p ~/maarch-optionb && cd ~/maarch-optionb
git clone --depth 1 --single-branch --branch main \
  https://github.com/cedlerouge/MaarchCourrier.git src   # 2301.3.x mirror
```
> The primary source is GitLab `labs.maarch.org`; use your usual Maarch source if
> reachable. The runtime Docker image is **not** a build source (no `angular.json`).

## 2. Apply the 4 Option B edits

All under `src/` (the app root). Copy the component from the plugin's `frontend/`:

```bash
P=src/src/frontend/app/actions/send-external-signatory-book-action
mkdir -p $P/ngsign
cp <PLUGIN>/frontend/ngsign.component.ts   $P/ngsign/
cp <PLUGIN>/frontend/ngsign.component.html $P/ngsign/
cp <PLUGIN>/frontend/ngsign.component.scss $P/ngsign/
```

Then the 3 one-line wirings (see `INSTALLATION.md` Step 5-bis for the exact snippets):
1. `src/src/frontend/app/app.module.ts` — import + add `NgsignComponent` to `declarations`.
2. `.../send-external-signatory-book-action.component.ts` — import + `@ViewChild('ngsign') ngsign: NgsignComponent;`.
3. `.../send-external-signatory-book-action.component.html` — add the `<app-ngsign #ngsign …>` element after `app-i-paraph`.

> No change to `executeAction()` / `isValidAction()`: they dispatch dynamically via
> `this[authService.externalSignatoryBook.id]`, and `#ngsign` (= the id) resolves it.

## 3. Build the SPA in a Node container

`node_modules` goes to a fast named volume; `dist/` comes out on the host. Detached so a
long build is not tied to your shell:

```bash
cd ~/maarch-optionb/src
docker run -d --name maarch-build \
  -v "$PWD":/app -v maarch_nm:/app/node_modules -w /app \
  node:20-bullseye-slim \
  sh -c "npm config set legacy-peer-deps true && npm ci --no-audit --no-fund && npm run build && echo BUILD_OK"

# follow it:
docker logs -f maarch-build      # wait for 'BUILD_OK' (~1–2 min build after npm ci)
```
Result: `~/maarch-optionb/src/dist/` (≈ 79 MB, `index.html` + hashed bundles). Sanity
check that the component made it in:
```bash
grep -rl "app-ngsign\|sentToNgsign" src/dist | head
```

## 4. Deploy into the running Maarch container

```bash
docker cp src/dist/. <maarch_container>:/var/www/html/MaarchCourrier/dist/
```
Add the label override (runtime, no rebuild):
```bash
docker exec <maarch_container> sh -c '
  mkdir -p /var/www/html/MaarchCourrier/custom/<customId>/lang
  printf "%s\n" "{\"sentToNgsign\":\"Envoyer à NGSign\",\"ngsign\":\"NGSign\"}" \
    > /var/www/html/MaarchCourrier/custom/<customId>/lang/lang-fr.json'
```

## 5. Deploy the Option B backend (same container)

```bash
C=<maarch_container>; ROOT=/var/www/html/MaarchCourrier
docker cp connector/src/app/external/externalSignatoryBook/ngsign $C:$ROOT/src/app/external/externalSignatoryBook/
docker cp config/remoteSignatoryBooks.ngsign-native.sample.xml    $C:$ROOT/modules/visa/xml/remoteSignatoryBooks.xml
# then apply the two ngsign dispatch patches (docs/PATCHES.md, Option B) inside the container,
# and the sql/ table if wanted.
```
Fill `<url>` + `<token>` in the XML, fix ownership so the web user can read the files
(INSTALLATION Step 6), reload PHP/opcache.

## 6. Run the end-to-end test

Follow `INSTALLATION.md` Step 9. Option-B-specific check first: open a mail with a
signable attachment → **Send to NGSign** → the dialog renders via `app-ngsign`, Validate
is enabled, and iParapheur still works in parallel. Then the full cycle: send → FRZ →
sign on NGSign → cron retrieval → `signed_response` + SIGN.

## 7. Cleanup

```bash
docker rm -f maarch-build 2>/dev/null; docker volume rm maarch_nm 2>/dev/null
# rm -rf ~/maarch-optionb   # the source clone (large)
```
