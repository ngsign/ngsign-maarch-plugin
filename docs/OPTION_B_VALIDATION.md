# Option B — end-to-end validation report

This documents a **full send → sign → retrieve cycle** run successfully against a live
Maarch Courrier **2301** instance with the native `ngsign` id (Option B), and the issues
found and fixed on the way. It complements `OPTION_B_FRONTEND_TEST.md` (how to build the
SPA) and `PATCHES.md` (the core patches).

## Result

The complete cycle works:

1. **Send** from the Maarch UI (action *"Envoyer sur la tablette"* → `app-ngsign` dialog →
   Validate) → an NGSign transaction is created and **launched** (status `CONFIGURED`), the
   signer receives the *BY_MAIL* signing email, and the attachment is frozen (`FRZ`) with
   its `external_id = "<transactionId>/<identifier>"`.
2. **Sign** on NGSign via the emailed link → transaction status becomes `SIGNED`.
3. **Retrieve** by the batch/cron `process_mailsFromSignatoryBook.php` → the signed PDF is
   downloaded and re-integrated as a **`signed_response`** attachment ("Réponse signée"),
   and the mail advances to `validatedStatus` (e.g. `EENV`).

## Environment used

- `maarch/maarchcourrier` runtime image (2301), Apache on **port 80 inside** the container
  (mapped to 8080 on the host), PostgreSQL 14.
- Option B `dist/` deployed; `ngsign` connector (`NgsignController` + `NgsignClient`)
  under `src/app/external/externalSignatoryBook/ngsign/`; the three core patches applied
  (`PATCHES.md`).

---

## Issues found & fixes (checklist for a clean install)

### 1. Send dialog empty / Validate greyed — **missing core patch** ⚠️ most important
- **Symptom:** the `app-ngsign` dialog opens but shows *"Aucun élément éligible : non
  intégré au parapheur, gelée, ou déjà signée"* and **Validate** stays disabled.
- **Cause:** `PreProcessActionController::checkExternalSignatoryBook()` branches on a
  hardcoded book-id whitelist that did **not** include `ngsign`, so it never loaded the
  attachments (`additionalsInfos.attachments = []`; front `isValidParaph()` → false).
- **Fix:** add `'ngsign'` to that `in_array` — **PATCHES.md → File 3**. This is a *third*
  core patch, in addition to the send/retrieve dispatch patches.

### 2. NGSign HTTP 404 on send — **wrong `<url>` in the XML**
- **Symptom:** `NGSign HTTP 404 ... path:/server/protected/transaction/pdfs`.
- **Cause:** `<url>` was set to `https://sandbox.ng-sign.com/server`. The client already
  prefixes every path with `/server/...`, so this produced a double `/server`.
- **Fix:** `<url>` must be the **host only** (`https://sandbox.ng-sign.com`) — no `/server`.
  Documented in the sample XML.

### 3. Retrieval "Connection refused" — **wrong `maarchUrl` in the batch config**
- **Symptom:** `technique.log`: *"Create attachment failed : Failed to connect to
  localhost port 8080: Connection refused"*; no `signed_response` created.
- **Cause:** `config.maarchUrl` pointed to the **host** URL `http://localhost:8080/`. The
  batch runs *inside* the app server and calls Maarch back over REST — where Apache listens
  on **port 80**, not the host-mapped 8080.
- **Fix:** `maarchUrl` = the app's **internal** URL (`http://localhost/`, or
  `http://localhost/<customId>/` for a custom path). See `INSTALLATION.md` Step 7.

### 4. Raw i18n labels — **missing language keys** (cosmetic)
- **Symptom:** the dialog shows the raw key `lang.sentToNgsign` (and `ngsign`,
  `ngsignWorkflow`).
- **Cause:** the Option B keys were not present in the language served to the SPA.
- **⚠️ Gotcha — the `custom/<customId>/lang/*` override may be silently ignored:** the SPA
  fetches merged translations from `GET /rest/languages/{lang}` =
  `src/lang/lang-{lang}.json` **+** `custom/<customId>/lang/lang-{lang}.json`, but only
  when `CoreConfigModel::getCustomId()` resolves a customId. For a **web request** that id
  comes from `custom/custom.json` (URL/host mapping); with no `custom/custom.json` (or an
  empty `config.json` "customID"), `getCustomId()` returns `''` and the custom override is
  **never merged** — even though the batch scripts *do* pick it up (they set
  `$GLOBALS['customId']`). So the file can be present and still have no effect in the UI.
- **Fix (choose one):**
  - add the keys to the **core** `src/lang/lang-fr.json` / `lang-en.json` (always served —
    what we did on the test instance), **or**
  - make `getCustomId()` resolve your customId for web requests (a `custom/custom.json`
    entry mapping the host/path to your id), then the `custom/<customId>/lang/*` override
    merges.
- Either way, **hard-reload** the SPA (Ctrl/Cmd+Shift+R) — translations are cached in the
  browser. Verify with `curl .../rest/languages/fr | grep sentToNgsign`.
- The plugin `lang/lang-fr.json` / `lang-en.json` now ship `ngsign`, `sentToNgsign`,
  `ngsignWorkflow`.

### 5. Tracking silently disabled — **`ngsign_transactions` table absent** (optional)
- **Symptom:** none functionally; `NgsignController::track()` swallows the failure
  ("tracking table is optional").
- **Cause:** `sql/001_ngsign_transactions.sql` was not run.
- **Fix:** run it (`INSTALLATION.md` Step 4) if you want the observability table. The flow
  itself does not depend on it — the NGSign ids live in the attachment's `external_id`.

### 6. NGSign sandbox latency (operational note)
- The sandbox is slow: `getTransaction`/upload can occasionally time out (~180 s). This is
  transient — the next cron tick retries. Keep the client's generous cURL timeouts.

---

## 100%-UI test recipe (once the install is correct)

Two attachment gestures are mandatory and easy to miss:

1. Login as the processing user → **home** → their group section → **"Courriers à traiter"**
   → open the mail (Traiter).
   > The action *"Envoyer sur la tablette"* is only offered for the **(group, basket)**
   > pairs it is bound to. Bind it to the group/basket the user actually works from (admin
   > *Baskets* → actions), otherwise it will not appear.
2. **Pièces jointes** → add the attachment with **Type = "Projet de réponse"** (a
   *signable* type — **not** "Pièce jointe" / `simple_attachment`).
3. On that attachment: **⋮ → "Intégrer au parapheur"** (`in_signature_book`); the pen icon
   + *"Visa/Signature"* tag must appear.
4. **Circuit de visa** → add a **signatory** whose Maarch account has a **real email**
   (NGSign emails the signing link there).
5. Bottom action **"Envoyer sur la tablette"** → `app-ngsign` dialog → **Validate**.
6. Sign via the email → wait for the retrieval cron (or run the batch) → the
   **"Réponse signée"** attachment appears on the mail.

**The two recurring traps:** (a) attachment type *"Pièce jointe"* instead of *"Projet de
réponse"*; (b) forgetting *"Intégrer au parapheur"*. Either one makes the send dialog
report "no eligible element".
