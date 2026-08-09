# NGSign × Maarch Courrier — Option B POC (Docker)

A ready-to-run proof of concept of the **NGSign** electronic-signature connector for
**Maarch Courrier 2301**, using the native `ngsign` integration (Option B). It bundles two
images:

| Image | Content |
|---|---|
| `DOCKERHUB_USER/ngsign-maarch-poc-app` | Maarch Courrier 2301 + the compiled Option B SPA + the `ngsign` connector + the 3 core patches + the retrieval cron (every 5 min) |
| `DOCKERHUB_USER/ngsign-maarch-poc-db`  | PostgreSQL 14, **self-seeding** with the Maarch demo database on first start |

> **Demo instance — not for production.** It ships well-known demo credentials
> (`superadmin`/`superadmin`, DB `maarch`/`maarch`) and no real secret. Do not expose it
> on a public network.

---

## 1. Set your NGSign token  ⚠️ required

The connector talks to NGSign with **two settings** kept in **`remoteSignatoryBooks.xml`**
(next to this README). Open it and edit:

```xml
<signatoryBook>
    <id>ngsign</id>
    <url>https://sandbox.ng-sign.com</url>          <!-- host ONLY, see note below -->
    <token>__YOUR_NGSIGN_API_TOKEN__</token>        <!-- ← paste your Bearer token here -->
    ...
</signatoryBook>
```

- **`<token>`** — your NGSign API token (Bearer / JWT). This is the only mandatory change.
- **`<url>`** — the NGSign server, **host only, WITHOUT the `/server` path**. The connector
  already prefixes every call with `/server/...`; adding it here yields a double `/server`
  → `HTTP 404`. Correct: `https://sandbox.ng-sign.com`. Wrong: `.../server`.

This file is **bind-mounted** into the app container, so after editing it just reload:

```bash
docker compose restart app
```

No rebuild needed. (Other settings — signature position, `defaultMode=BY_MAIL`, statuses…
— have sensible defaults in the same file.)

---

## 2. Start

```bash
docker compose up -d
# first start seeds the DB (~20-40 s); follow readiness:
docker compose logs -f app
```

Then open **http://localhost:8080**.

| Role | Login | Password |
|---|---|---|
| Admin | `superadmin` | `superadmin` |
| Demo processing user | `ssaporta` | `maarch` |

---

## 3. Run the full signature test (send → sign → retrieve)

Log in as **`ssaporta` / `maarch`**, then follow the 100%-UI recipe in
[`../docs/OPTION_B_VALIDATION.md`](../docs/OPTION_B_VALIDATION.md). In short:

1. Home → **Courriers à traiter** → open a mail → **Traiter**.
2. **Pièces jointes** → add a PDF with **Type = "Projet de réponse"** (a *signable* type).
3. On it: **⋮ → "Intégrer au parapheur"** (pen icon + "Visa/Signature" tag appears).
4. **Circuit de visa** → add a **signatory** with a **real email** (NGSign emails the link
   there — see §4 to set it).
5. Bottom action **"Envoyer sur la tablette"** → the `app-ngsign` dialog → **Validate**.
6. Sign via the email you receive.
7. The **retrieval cron runs every 5 min**; the signed PDF comes back as a **"Réponse
   signée"** attachment on the mail. (To trigger it immediately, see §5.)

## 4. Set a real signer email

Demo users ship with a placeholder email (`yourEmail@domain.com`). Give your chosen
signatory a real address so NGSign can reach them — as `superadmin`, in the user admin, or:

```bash
docker compose exec db psql -U maarch -d maarch_courrier \
  -c "UPDATE users SET mail='you@example.com' WHERE user_id='ddaull';"
```

## 5. Retrieval batch / cron

Signed documents are pulled back by `bin/signatureBook/process_mailsFromSignatoryBook.php`,
scheduled **every 5 minutes** (`/etc/cron.d/ngsign` inside the app container, logs to
`/tmp/ngsign_cron.log`). To run it on demand:

```bash
docker compose exec -u www-data app \
  sh -c 'cd /var/www/html/MaarchCourrier && php bin/signatureBook/process_mailsFromSignatoryBook.php \
         -c bin/signatureBook/ngsign_batch_config.json'
```

The batch calls Maarch back over REST at its **internal** URL (`http://localhost/`, i.e.
Apache on port **80** inside the container — *not* the host-mapped `8080`). This is already
configured in `ngsign_batch_config.json`.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Send dialog: *"Aucun élément éligible"* / **Validate** greyed | The attachment must be a **signable type** ("Projet de réponse") **and** "Intégré au parapheur". |
| `NGSign HTTP 404 … /server/protected/…` | `<url>` has a stray `/server` — remove it (host only). |
| No signature email | The signatory's Maarch account has no real email (§4). |
| Retrieval "Connection refused" | `maarchUrl` must be the internal URL (`http://localhost/`), already set. |
| Label shows `lang.sentToNgsign` | Hard-reload the browser (translations are cached). |

See [`../docs/OPTION_B_VALIDATION.md`](../docs/OPTION_B_VALIDATION.md) for the full
symptom → cause → fix list.

## Reset

```bash
docker compose down -v      # also wipes the DB + docservers volumes → fresh seed next up
```
