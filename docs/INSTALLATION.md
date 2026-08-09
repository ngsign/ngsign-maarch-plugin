# Installing the NGSign connector on a Maarch instance (without Docker)

This procedure applies to **any Maarch Courrier 2301 installation** (bare-metal, VM,
container…). All commands are to be run **on the Maarch server**.

## Conventions

| Token | Example | Adapt to |
|---|---|---|
| `<MAARCH_ROOT>` | `/var/www/html/MaarchCourrier` | the application root |
| `<customId>` | `maarch` | your custom id (folder under `custom/`) |
| `<WEB_USER>` / `<WEB_GROUP>` | `www-data` (Debian) / `apache` (RHEL) | the web server user/group |
| `<DB_*>` | — | Maarch's PostgreSQL host / db / user |

> Make a **backup** of the 2 modified files (§3) and a **database dump** before starting.

## Prerequisites
- Maarch Courrier **2301** installed and running.
- **PHP 8.1** with the **cURL** extension (`php -m | grep curl`).
- Access to Maarch's **PostgreSQL** (psql).
- An **NGSign account** with an **API token** (Bearer) and the "transaction" feature
  enabled.

---

## Step 1 — Copy the connector code

Copy the `connector/src/app/external/externalSignatoryBook/ngsign/` folder from the
package into the Maarch tree:

```bash
cp -r connector/src/app/external/externalSignatoryBook/ngsign \
      <MAARCH_ROOT>/src/app/external/externalSignatoryBook/
```

Expected result:
```
<MAARCH_ROOT>/src/app/external/externalSignatoryBook/ngsign/
├── controllers/NgsignController.php
└── Infrastructure/NgsignClient.php
```
The `ExternalSignatoryBook\ngsign\…` namespace resolves automatically (PSR-4).
**No `composer dump-autoload`.**

---

## Step 2 — Configure the parapheur

Edit (or create) the file:
```
<MAARCH_ROOT>/modules/visa/xml/remoteSignatoryBooks.xml
```
> If it already exists for your custom:
> `<MAARCH_ROOT>/custom/<customId>/modules/visa/xml/remoteSignatoryBooks.xml`
> (this path takes precedence).

Start from the template matching the chosen option (see TECHNICAL_MANUAL.md §3):
- **Option A (fast, no rebuild)**: `config/remoteSignatoryBooks.iparapheur-slot.sample.xml`
- **Option B (native, with a frontend component)**: `config/remoteSignatoryBooks.ngsign-native.sample.xml`

Fill in **the only 2 external settings**: `<url>` (NGSign server) and `<token>` (API
token). Example (Option A):
```xml
<signatoryBookEnabled>iParapheur</signatoryBookEnabled>
<signatoryBook>
    <id>iParapheur</id>
    <url>https://sandbox.ng-sign.com</url>
    <token>YOUR_API_TOKEN</token>
    ...
    <choosePosition>true</choosePosition>
    ...
</signatoryBook>
```

---

## Step 3 — Apply the dispatch patches

Modify the core files as described in `docs/PATCHES.md`:
1. `<MAARCH_ROOT>/src/app/action/controllers/ExternalSignatoryBookTrait.php`
   (route the send to `NgsignController::sendDatas`).
2. `<MAARCH_ROOT>/bin/signatureBook/process_mailsFromSignatoryBook.php`
   (whitelist + route the retrieval to `NgsignController::retrieveSignedMails`).
3. **Option B only** — `<MAARCH_ROOT>/src/app/action/controllers/PreProcessActionController.php`
   (add `'ngsign'` to the `checkExternalSignatoryBook()` whitelist so the send dialog lists
   the signable attachments; **without it the dialog shows "no eligible element" and
   Validate stays greyed out** — see PATCHES §File 3).

Check the syntax after editing:
```bash
php -l <MAARCH_ROOT>/src/app/action/controllers/ExternalSignatoryBookTrait.php
php -l <MAARCH_ROOT>/bin/signatureBook/process_mailsFromSignatoryBook.php
php -l <MAARCH_ROOT>/src/app/action/controllers/PreProcessActionController.php   # Option B
php -l <MAARCH_ROOT>/src/app/external/externalSignatoryBook/ngsign/controllers/NgsignController.php
php -l <MAARCH_ROOT>/src/app/external/externalSignatoryBook/ngsign/Infrastructure/NgsignClient.php
```

---

## Step 4 — Create the tracking table

```bash
psql -h <DB_HOST> -U <DB_USER> -d <DB_NAME> -f sql/001_ngsign_transactions.sql
```
(Optional observability table; the flow does not depend on it — the NGSign id is stored
in the attachments' `external_id`.)

---

## Step 5 — "NGSign" labels in the UI (Option A)

> **Which step 5 applies to you?**
> - **Option A** (reuse the iParapheur slot, no rebuild): do **Step 5** below.
> - **Option B** (native `ngsign` id): **skip 5.1**, do **Step 5-bis** (frontend
>   component + `ng build`) instead, then still do **5.2** (action label).

Without recompiling, replace the "iParapheur" labels with "NGSign":

**5.1** Translation override — copy the language files:
```bash
mkdir -p <MAARCH_ROOT>/custom/<customId>/lang
cp lang/lang-fr.json <MAARCH_ROOT>/custom/<customId>/lang/lang-fr.json
cp lang/lang-en.json <MAARCH_ROOT>/custom/<customId>/lang/lang-en.json
```
(Maarch merges these overrides when loading translations; keys: `iParapheur`,
`sentToIParapheur`.)

**5.2** Rename the action label (SQL):
```sql
UPDATE actions
SET label_action = 'Send to NGSign (electronic signature)'
WHERE component = 'sendExternalSignatoryBookAction';
```

---

## Step 5-bis — Frontend component + rebuild (Option B only)

> **Do this only for Option B** (native `ngsign` id). Option A does **not** need any of
> this. This is the step that was missing when "no integration procedure is given before
> `ng build`".
>
> **Verified** against Maarch Courrier **2301** (2301.1.x and 2301.3.x). The 4 wiring
> edits below are the *exact* changes; the plugin ships the ready component under
> `frontend/`. A full reproduction (clone → edit → `ng build`) is in
> `docs/OPTION_B_FRONTEND_TEST.md`.

**Why**: the Angular SPA renders one sub-component per parapheur id
(`app-maarch-paraph`, `app-i-paraph`, `app-ixbus-paraph`, `app-fast-paraph`…). We add an
`app-ngsign` sub-component — a faithful copy of the generic **iParapheur** one — declare
it, reference it in the send action, then rebuild the SPA.

> **Key fact (2301)**: the send action dispatches **dynamically** via
> `this[authService.externalSignatoryBook.id]` (see `executeAction()` /
> `isValidAction()`). So the `@ViewChild` **template-ref name must be exactly `ngsign`**
> (= the config id) — and **`executeAction()` / `isValidAction()` need NO change**. You
> only add a component + one `@ViewChild` + one template element + one module entry.

**Prerequisites**
- The Maarch **frontend build sources** (the whole app root: `package.json`,
  `angular.json`, `src/frontend/`, `tsconfig*.json`).
- **Node / npm** per the app root `package.json` → `engines`:
  - **2301.1.x** → Node **≥ 18.7**, npm ≥ 8.15
  - **2301.3.x** → Node **≥ 20.9**, npm ≥ 10.1
- The build runs from the **app root** (not `src/frontend/`); output goes to `dist/`.

> ⚠️ **Docker note**: the `maarch/maarchcourrier` **runtime** image ships the *compiled*
> `dist/` but **no `angular.json` and no Node/Angular toolchain** — you **cannot**
> `ng build` inside it. Build **outside** (host or a `node:20` container) from the
> matching source, then copy the resulting `dist/` into the container (see the test doc).

### 5b.1 — Add the `ngsign` component
Create `src/frontend/app/actions/send-external-signatory-book-action/ngsign/` with
`ngsign.component.{ts,html,scss}` — copy them from the plugin's **`frontend/`** folder
(they are a faithful copy of `i-paraph/`, same public contract:
`isValidParaph()`, `getRessources()`, `getDatas()`, inputs `additionalsInfos` /
`externalSignatoryBookDatas`). The only differences vs `i-paraph` are the selector
(`app-ngsign`), the class (`NgsignComponent`) and the label key (`lang.sentToNgsign`).

### 5b.2 — Declare it in `app.module.ts`
`src/frontend/app/app.module.ts` — next to `IParaphComponent`:
```ts
import { NgsignComponent } from './actions/send-external-signatory-book-action/ngsign/ngsign.component';
// …in @NgModule declarations, right after IParaphComponent:
        IParaphComponent,
        NgsignComponent,
```

### 5b.3 — Reference it in the send action (`.ts`)
`.../send-external-signatory-book-action.component.ts`:
```ts
import { NgsignComponent } from './ngsign/ngsign.component';
// …next to the other @ViewChild refs (ref name MUST be `ngsign`):
    @ViewChild('ngsign', { static: false }) ngsign: NgsignComponent;
```
> No other change here — `executeAction()` and `isValidAction()` already resolve
> `this['ngsign']` on their own.

### 5b.4 — Reference it in the send action (`.html`)
`.../send-external-signatory-book-action.component.html` — right after the `app-i-paraph`
element (`#ngsign` matches the id so dynamic dispatch works):
```html
<app-ngsign #ngsign *ngIf="authService.externalSignatoryBook.id === 'ngsign' && !loading"
    [additionalsInfos]="additionalsInfos"
    [externalSignatoryBookDatas]="externalSignatoryBookDatas">
</app-ngsign>
```

### 5b.5 — Build the SPA (from the app root)
```bash
cd <MAARCH_ROOT>
npm config set legacy-peer-deps true
npm ci                         # first time; installs Angular 14 toolchain
npm run build                  # = ng build --project "maarchCourrier"  → dist/
# production bundle (hashed), to match a runtime deploy:
#   npm run build-prod         # = ng build … --configuration production
```
The bundle lands in `<MAARCH_ROOT>/dist/`. On a Docker runtime instance, copy it in:
```bash
docker cp dist/. <maarch_container>:/var/www/html/MaarchCourrier/dist/
```
Then hard-refresh the browser (check the new bundle hash).

### 5b.6 — Label (runtime, no rebuild)
The dialog uses the backend translation key `sentToNgsign` (served to the SPA from
`src/lang/lang-*.json`). Add it via the custom override — **no rebuild needed**:
```bash
mkdir -p <MAARCH_ROOT>/custom/<customId>/lang
```
In `custom/<customId>/lang/lang-fr.json` and `lang-en.json`, add e.g.:
```json
{ "sentToNgsign": "Envoyer à NGSign", "ngsign": "NGSign" }
```

### 5b.7 — Check the backend matches Option B
- config: `config/remoteSignatoryBooks.ngsign-native.sample.xml` (`<id>ngsign</id>`),
- dispatch patches: the **`ngsign`** branches in `docs/PATCHES.md` (File 1 + File 2),
- whitelist in `process_mailsFromSignatoryBook.php` includes `'ngsign'` (PATCHES §2.1).

> **Verify**: trigger "Send to NGSign" on a mail with a signable attachment — the dialog
> opens via `app-ngsign` and "Validate" is enabled. The rest of the end-to-end flow
> (Step 9) is identical to Option A.

---

## Step 6 — File permissions

Align with Maarch's convention (files readable by the web server):
```bash
chown -R root:<WEB_GROUP> <MAARCH_ROOT>/src/app/external/externalSignatoryBook/ngsign
find <MAARCH_ROOT>/src/app/external/externalSignatoryBook/ngsign -type f -exec chmod 660 {} \;
find <MAARCH_ROOT>/src/app/external/externalSignatoryBook/ngsign -type d -exec chmod 770 {} \;
chown root:<WEB_GROUP> <MAARCH_ROOT>/modules/visa/xml/remoteSignatoryBooks.xml \
                       <MAARCH_ROOT>/src/app/action/controllers/ExternalSignatoryBookTrait.php \
                       <MAARCH_ROOT>/bin/signatureBook/process_mailsFromSignatoryBook.php
chmod 660 <MAARCH_ROOT>/modules/visa/xml/remoteSignatoryBooks.xml
```
> **Important**: after copying any file, re-check that the **web server** can read it
> (otherwise a "Trait/Class not found" error occurs at runtime).

Reload PHP/opcache: `systemctl reload apache2` (or `php-fpm`).

---

## Step 7 — Automatic retrieval (cron)

**7.1** Create the batch config file from
`batch/ngsign-retrieve.config.sample.json`, then install it:
```bash
cp batch/ngsign-retrieve.config.sample.json \
   <MAARCH_ROOT>/bin/signatureBook/ngsign-retrieve.config.json
```
Adapt:
- `config.maarchDirectory` → `<MAARCH_ROOT>/` (with the trailing `/`),
- `config.customID` → `<customId>`,
- `config.maarchUrl` → the app's internal URL (e.g. `http://localhost/<customId>/`),
- `signatureBook.userWS` / `passwordWS` → a **Maarch user** allowed to create
  attachments via the REST API (basic auth).

**7.2** Schedule (e.g. every 3 min) — `/etc/cron.d/ngsign-retrieve`:
```cron
*/3 * * * * <WEB_USER> php <MAARCH_ROOT>/bin/signatureBook/process_mailsFromSignatoryBook.php -c <MAARCH_ROOT>/bin/signatureBook/ngsign-retrieve.config.json >> /var/log/ngsign-retrieve.log 2>&1
```
```bash
touch /var/log/ngsign-retrieve.log && chown <WEB_USER>:<WEB_GROUP> /var/log/ngsign-retrieve.log
chmod 644 /etc/cron.d/ngsign-retrieve
systemctl reload cron   # or: service cron reload
```

> **⚠️ Maarch log permissions** — the batch (i.e. `<WEB_USER>`) must be able to write the
> application log `technique.log` (at the root `<MAARCH_ROOT>`). If you ran the batch
> **manually as root** beforehand, that file will be owned by `root` and the cron (run as
> `<WEB_USER>`) will fail with *"technique.log … Permission denied"* **before** any
> retrieval. Fix:
> ```bash
> chown <WEB_USER>:<WEB_GROUP> <MAARCH_ROOT>/technique.log && chmod 664 <MAARCH_ROOT>/technique.log
> ```
> General rule: **always run the batch as the same user as the cron**
> (`sudo -u <WEB_USER> php …`).

---

## Step 8 — Functional configuration in Maarch (admin)

1. **Signature privilege**: grant the writers' group the `sign_document` and
   `visa_documents` rights (Administration → Groups), otherwise no signer can be selected
   in the visa circuit.
2. **Signer e-mail**: set a real address on the signer user (Administration → Users).
3. **Action → basket**: attach the "Send to NGSign" action to the desired basket
   (Administration → … → basket actions).

---

## Step 9 — End-to-end verification

1. Create a mail with a **signable attachment** (e.g. "Response project" PDF).
2. Add a **visa circuit** with a **Signer** (who has an e-mail).
3. From the basket, trigger the **"Send to NGSign"** action → **Validate**.
   → The attachment moves to **FRZ**; a transaction is created on NGSign.
4. The signer receives the invitation, **places their signature** and signs.
5. Wait for the cron (≤ 3 min) — or run the batch manually (§7).
   → A **`signed_response`** attachment appears, the original moves to **SIGN**.

Diagnostics: `tail -f /var/log/ngsign-retrieve.log` and the Maarch application logs
(`custom/<customId>/.../technique.log`).

---

## Uninstall / rollback

1. Restore the 2 original core files (`ExternalSignatoryBookTrait.php`,
   `process_mailsFromSignatoryBook.php`).
2. Set `<signatoryBookEnabled>` back to the previous parapheur (or empty).
3. Remove the cron `/etc/cron.d/ngsign-retrieve`.
4. (Optional) Remove the `ngsign/` folder, the `ngsign_transactions` table, the language
   override.
