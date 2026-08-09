# Maarch dispatch patches — NGSign

Three Maarch core files must be modified: two to route the send and the retrieval to
`NgsignController`, and — **for Option B only** — a third so the send dialog recognises
the `ngsign` id and lists the signable attachments. Depending on the chosen **option**
(see `TECHNICAL_MANUAL.md`), the id used is `iParapheur` (Option A, reuse of the UI slot,
no rebuild) or `ngsign` (Option B, native id, requires a frontend component).

> Line numbers are indicative (Maarch Courrier 2301 baseline); locate the blocks by their
> content.

---

## File 1 — `src/app/action/controllers/ExternalSignatoryBookTrait.php`

Method `sendExternalSignatoryBookAction()`, `if / elseif` chain on `$config['id']`.

### Option A — reuse the `iParapheur` slot
Replace the call in the `iParapheur` case:

```php
// BEFORE
} elseif ($config['id'] == 'iParapheur') {
    $sentInfo = IParapheurController::sendDatas([
        'config'      => $config,
        'resIdMaster' => $args['resId']
    ]);
}

// AFTER
} elseif ($config['id'] == 'iParapheur') {
    $sentInfo = \ExternalSignatoryBook\ngsign\controllers\NgsignController::sendDatas([
        'config'      => $config,
        'resIdMaster' => $args['resId']
    ]);
}
```

### Option B — native `ngsign` id
Add a dedicated case at the end of the chain (before the final `}`), leaving `iParapheur`
untouched:

```php
} elseif ($config['id'] == 'ngsign') {
    $sentInfo = \ExternalSignatoryBook\ngsign\controllers\NgsignController::sendDatas([
        'config'      => $config,
        'resIdMaster' => $args['resId']
    ]);
}
```

---

## File 2 — `bin/signatureBook/process_mailsFromSignatoryBook.php`

This batch retrieves the signed documents. Two places.

### 2.1 Parapheur whitelist (one line)
```php
// BEFORE
if (!in_array($configRemoteSignatoryBook['id'], ['maarchParapheur', 'xParaph', 'fastParapheur', 'iParapheur', 'ixbus'])) {

// AFTER (Option B only; in Option A, 'iParapheur' is already present)
if (!in_array($configRemoteSignatoryBook['id'], ['maarchParapheur', 'xParaph', 'fastParapheur', 'iParapheur', 'ixbus', 'ngsign'])) {
```

### 2.2 Retrieval dispatch (TWO blocks: attachments + main document)
There are two `if/elseif` chains: one for attachments (`version => 'noVersion'`) and one
for the main document (`version => 'resLetterbox'`).

**Option A** — in BOTH blocks, replace the `iParapheur` call:
```php
// BEFORE (x2)
\ExternalSignatoryBook\controllers\IParapheurController::retrieveSignedMails(...)
// AFTER (x2)
\ExternalSignatoryBook\ngsign\controllers\NgsignController::retrieveSignedMails(...)
```

**Option B** — in BOTH blocks, add an `ngsign` branch:
```php
// attachments block
} elseif ($configRemoteSignatoryBook['id'] == 'ngsign') {
    $retrievedMails = \ExternalSignatoryBook\ngsign\controllers\NgsignController::retrieveSignedMails(['config' => $configRemoteSignatoryBook, 'idsToRetrieve' => $idsToRetrieve, 'version' => 'noVersion']);
}

// main document block
} elseif ($configRemoteSignatoryBook['id'] == 'ngsign') {
    $retrievedLetterboxMails = \ExternalSignatoryBook\ngsign\controllers\NgsignController::retrieveSignedMails(['config' => $configRemoteSignatoryBook, 'idsToRetrieve' => $idsToRetrieve, 'version' => 'resLetterbox']);
}
```

---

## File 3 — `src/app/action/controllers/PreProcessActionController.php` (Option B only)

Method `checkExternalSignatoryBook()`. When the user runs the "Send to signatory book"
action, this pre-process builds the list of signable attachments shown in the dialog
(`additionalsInfos.attachments`). It branches on the enabled book id via a **hardcoded
whitelist**; an id absent from it produces an empty list.

**Symptom if this patch is missing (Option B):** the `app-ngsign` dialog opens but shows
*"Aucun élément éligible / No eligible element"* (or the attachment list is empty) and the
**Validate** button stays greyed out — even though the attachment is a signable type and
flagged *in signature book*. The front `NgsignComponent.isValidParaph()` returns `false`
because `additionalsInfos.attachments.length === 0`.

### Option A — reuse the `iParapheur` slot
No change: `iParapheur` is already in the whitelist.

### Option B — native `ngsign` id
Add `'ngsign'` to the `in_array` whitelist (the branch that loads attachments — the same
one used by `maarchParapheur`):

```php
// BEFORE
if (in_array($signatureBookEnabled, ['maarchParapheur', 'fastParapheur', 'iParapheur', 'ixbus'])) {

// AFTER
if (in_array($signatureBookEnabled, ['maarchParapheur', 'fastParapheur', 'iParapheur', 'ixbus', 'ngsign'])) {
```

> This branch already applies exactly the filters `NgsignController::sendDatas()` expects
> (signable `attachment_type`, `in_signature_book = 'true'`, converted-to-PDF, file present
> on the docserver), so no further change is needed.

Check syntax after editing:
```bash
php -l <MAARCH_ROOT>/src/app/action/controllers/PreProcessActionController.php
```

---

## Reminder: re-integration is generic
No other batch modification is required. Once `retrieveSignedMails()` returns
`status='validated' + encodedFile` (signed PDF as base64), Maarch automatically
re-integrates the file (a `signed_response` attachment for attachments, an `adr_letterbox`
row of type `SIGN` for the main document).
