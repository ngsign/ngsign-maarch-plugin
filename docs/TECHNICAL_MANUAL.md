# Technical Manual — NGSign connector for Maarch Courrier

**Purpose**: integrate **NGSign** (electronic-signature parapheur) into **Maarch
Courrier**, reusing Maarch's native *external signatory book* framework.

**Validated target version**: Maarch Courrier **2301**. The approach remains valid on
nearby versions; verify the signatures of the parapheur framework methods before
production use on a different version.

**Status**: functional POC, full cycle validated end to end (send → signature →
retrieval of the signed document).

---

## 1. Overview

Maarch Courrier already talks to several parapheurs (Maarch Parapheur, FAST, iParapheur,
iXBus, xParaph). Each is integrated at **two levels**:

1. **Backend**: a *controller* class implementing two methods:
   - `sendDatas()` — pushes the document to the parapheur,
   - `retrieveSignedMails()` — retrieves the signed document.
2. **Frontend**: a dedicated Angular component for the send dialog.
3. **Configuration**: an XML file (`modules/visa/xml/remoteSignatoryBooks.xml`) that
   **enables** one parapheur and carries its settings.

The NGSign connector provides **the backend** (`NgsignController` + `NgsignClient`) and
**the configuration**. For the frontend, see the integration choice (§3).

```
Maarch Courrier
  └─ Action "Send to an external signatory book"
       └─ ExternalSignatoryBookTrait  →  NgsignController::sendDatas()
            ├─ fetches the PDF of the signable attachment
            ├─ POST /transaction/pdfs        (base64 upload)
            ├─ POST /transaction/{id}/launch (configure + launch)
            └─ freezes the attachment, stores external_id = "transactionId/identifier"

  (the signer signs on NGSign)

  └─ Batch process_mailsFromSignatoryBook.php (cron)
       └─ NgsignController::retrieveSignedMails()
            ├─ GET /transaction/{id}         (status)
            ├─ if SIGNED → GET /transaction/{id}/pdfs/{identifier} (signed PDF)
            └─ Maarch re-integrates → `signed_response` attachment
```

---

## 2. Delivered components

| File | Role |
|---|---|
| `connector/src/app/external/externalSignatoryBook/ngsign/controllers/NgsignController.php` | Send + retrieve logic (Maarch native contract) |
| `connector/src/app/external/externalSignatoryBook/ngsign/Infrastructure/NgsignClient.php` | NGSign HTTP client (upload / launch / get / download) |
| `config/remoteSignatoryBooks.*.sample.xml` | Configuration templates (2 options) |
| `sql/001_ngsign_transactions.sql` | Tracking table (observability) |
| `lang/lang-{fr,en}.json` | Label override (display "NGSign" in the UI) |
| `batch/ngsign-retrieve.config.sample.json` | Retrieval batch configuration |
| `docs/PATCHES.md` | Exact edits of the 2 core files |
| `docs/INSTALLATION.md` | Step-by-step install procedure (**without Docker**) |

The `ExternalSignatoryBook\ngsign\…` namespace resolves automatically: Maarch already
maps the PSR-4 prefix `ExternalSignatoryBook\` to
`src/app/external/externalSignatoryBook/`. **No `composer dump-autoload` is required.**

---

## 3. Frontend integration — two options

Adding a **brand-new** parapheur to the Angular UI requires writing a dedicated component
**and rebuilding the SPA**. Two strategies:

### Option A — Reuse the iParapheur "slot" (recommended for a POC / quick rollout)
- Enable the **`iParapheur`** id in the config, filled with NGSign settings.
- **Repoint the backend** of the `iParapheur` case to `NgsignController`.
- The iParapheur send dialog (component `app-i-paraph`) is **generic**: it validates as
  soon as there is a signable attachment, with no input and no provider-specific call.
- **No Angular rebuild.** The "iParapheur" labels are replaced by "NGSign" via a simple
  translation override (JSON file) plus the action label.
- **Trade-off**: the instance can no longer drive the real Libriciel iParapheur in
  parallel.

### Option B — Native `ngsign` id (recommended for productization)
- Clean, dedicated `ngsign` id, coexisting with all other parapheurs.
- Requires an Angular **`ngsign` component** (tiny: `isValidParaph()` returns `true`, no
  input) referenced in `send-external-signatory-book-action.component.ts` and its
  template, then an `ng build` of the SPA.

> The POC uses **Option A**. The backend code is identical in both cases; only the config
> and the dispatch patch differ (see `PATCHES.md`).

---

## 4. NGSign API mapping

Authentication: header `Authorization: Bearer <token>`.

| Step | Call | Body / Response |
|---|---|---|
| Upload PDF | `POST /server/protected/transaction/pdfs` | `[{fileName, fileExtension:"pdf", fileBase64}]` → `{"object":{"uuid":…, "pdfs":[{"identifier":…}]}}` |
| Configure + launch | `POST /server/protected/transaction/{uuid}/launch` | `{"sigConf":[{signer, sigType, choosePosition, docsConfigs:[{documentName, documentExtension, identifier, [page,xAxis,yAxis]}], mode, otp}]}` |
| Status | `GET /server/any/transaction/{uuid}` | `{"object":{"status":"CONFIGURED|SIGNED|…", "signers":[…]}}` |
| Download signed | `GET /server/any/transaction/{uuid}/pdfs/{identifier}` | **raw PDF bytes** (the `content-type` header is sometimes wrongly `application/json`) |

Findings observed during the POC:
- **`transactionId` = `object.uuid`** and **`identifier` = `object.pdfs[0].identifier`**
  (everything is wrapped in `object`).
- The download response returns **raw PDF bytes** despite an `application/json`
  `content-type` — do not trust the header.
- **Statuses**: `CONFIGURED` = awaiting signature (normal); `SIGNED` once signed. The
  lists of "signed"/"refused" statuses are **configurable** in the XML (`signedStates`,
  `refusedStates`).
- **Sandbox slowness**: the upload can take **~80 s**. Client timeouts are set to
  *connect=30 s / total=240 s*.
- **"transaction" feature**: the NGSign API account must have transaction dispatch
  enabled.

---

## 5. Signature position

Two modes, driven by `<choosePosition>` in the config:

- `true` (default) — **interactive placement**: NGSign shows the document to the signer,
  who **positions** the signature themselves. No coordinates are sent.
- `false` — **fixed position**: the signature is placed at `defaultPage` /
  `defaultXAxis` / `defaultYAxis`.

---

## 6. Backend contract (method details)

### `NgsignController::sendDatas(array $args): array`
Input: `['config' => $config, 'resIdMaster' => int]` where `$config['data']` is the XML
block of the parapheur (url, token, defaults…).
Processing: selects signable attachments (converted to PDF), resolves the signer from the
**`sign`** step of the visa circuit (`listinstance.item_mode='sign'` → user
email/last/first/phone), sends each document (upload + launch).
Output: `['sended' => ['attachments_coll' => [resId => "uuid/identifier"], 'letterbox_coll' => […]], 'historyInfos' => …]`
or `['error' => string]`. Maarch freezes the attachment and stores
`external_id.signatureBookId`.

### `NgsignController::retrieveSignedMails(array $args): array`
Input: `['config' => …, 'idsToRetrieve' => [version => [resId => ['external_id' => "uuid/identifier", …]]], 'version' => 'noVersion'|'resLetterbox']`.
Processing: for each id, `GET /transaction/{uuid}` → if status ∈ `signedStates`,
`GET …/pdfs/{identifier}` → signed PDF as base64.
Output: the `idsToRetrieve` structure enriched with `status`
(`validated`/`refused`/`waiting`), `format='pdf'`, `encodedFile` (base64), `notes`.
Re-integration is performed by the batch.

---

## 7. Retrieval: polling (cron)

There is **no webhook** in this POC. A standard Maarch batch polls NGSign:

```
php bin/signatureBook/process_mailsFromSignatoryBook.php -c <path/config.json>
```

Scheduled via **cron** (the POC: every 3 min). The `config.json` carries the Maarch
directory, the `customId`, the application URL, and a **web-service user** (basic auth)
used to recreate the signed attachment via the REST API.

Possible evolution: **NGSign webhook** → a custom REST endpoint triggers retrieval of a
transaction as soon as it is signed (instant notification).

---

## 8. Functional prerequisites in Maarch

For a user to send a document for signature via the UI:
1. The writer's **group** must hold the **`sign_document`** privilege (and
   `visa_documents`) — otherwise no user appears as a possible signer in the visa circuit.
2. The **signer user** must have a **valid e-mail** (NGSign emails the invitation in
   `BY_MAIL` mode).
3. The **action** "Send to an external signatory book" (`sendExternalSignatoryBookAction`)
   must be **attached to a basket** the writer uses.
4. The mail must carry a **signable attachment** (type `signable=true`, e.g.
   "Response project") and a **visa circuit with a signature step**.

---

## 9. POC limitations & productization recommendations

- **Frontend**: Option A hijacks the iParapheur slot. For a true "NGSign" brand in the UI
  and coexistence with iParapheur, build the Angular `ngsign` component (Option B) and
  recompile.
- **Single signer** handled (the `sign` step of the circuit). To support several
  sequential/parallel signers, iterate over the `sign` steps and build several `sigConf`
  entries.
- **Polling** vs **webhook** (real time).
- **OTP / BY_LINK mode / sigType** are exposed in configuration but not surfaced in the UI.
- **Security**: the API token is stored in clear text in the XML (restrict file
  permissions); for production, consider a vault / environment variable.
- **Maarch version compatibility**: re-check the parapheur framework method signatures.

---

## 10. What was validated (POC)

- Full send from the UI: upload + launch → attachment frozen, NGSign transaction created
  with the signer.
- Real signature by the signer (NGSign status `SIGNED`).
- Automatic retrieval (cron): download of the signed PDF and **re-integration** into
  Maarch (new `signed_response` attachment, original moved to `SIGN`).
- **Interactive** signature placement (`choosePosition=true`) validated against the API.
- "NGSign" UI labels (badge + action) without recompilation.
