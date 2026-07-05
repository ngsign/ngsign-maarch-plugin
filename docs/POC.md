# POC / Demo instance

A **ready-to-run, preconfigured Maarch Courrier 2301** Docker instance with the NGSign
connector already installed and wired (Option A — iParapheur-slot mode). Use it to
**demo or evaluate** the full electronic-signature cycle without doing the manual
installation.

> This is the *demonstration* artifact. To integrate NGSign into an existing Maarch
> instance, follow `docs/INSTALLATION.md` instead.

## What's inside

The bundle (`poc/maarch-ngsign-export.tar.gz`) is a full clone of a working instance:
Maarch app + PostgreSQL + docservers (3 Docker volumes) + `docker-compose.yml` +
`restore.sh`. It already contains:

- the NGSign connector (backend) + dispatch patches,
- the config (`remoteSignatoryBooks.xml`, iParapheur slot),
- the "NGSign" UI labels,
- the retrieval **cron** (every 3 min),
- the functional prerequisites (signature privilege on the demo group, a business user
  with a real e-mail, the parapheur action on a reachable basket).

> ⚠️ The bundle is ~233 MB — larger than GitHub's 100 MB file limit — so it is **not**
> committed to git. Distribute it as a **GitHub Release asset** (or via Git LFS). If you
> received the repo without it, ask for the release asset.

## Requirements

- Docker + `docker compose`
- An **NGSign API token** (Bearer) with the "transaction" feature enabled

## Run it

```bash
# from the poc/ folder
tar xzf maarch-ngsign-export.tar.gz
cd maarch-ngsign-export
./restore.sh
```

`restore.sh` recreates the 3 volumes and starts the stack. Then open:

**http://localhost:8081/maarch/dist/index.html**

| Account | Login | Password | Use |
|---|---|---|---|
| Admin | `superadmin` | `maarch` | administration only |
| Business user | `bblier` | `maarch` | create mail, sign, demo |

## Set your NGSign token (required)

The token was **scrubbed** from the bundle for safety, so set your own:

```bash
# 1) in the compose env (used by the polling script)
#    edit maarch-ngsign-export/.env  ->  NGSIGN_TOKEN=<your token>

# 2) in the connector config (the value actually used to call NGSign)
docker exec maarch sed -i \
  's#<token>[^<]*</token>#<token>YOUR_NGSIGN_API_TOKEN</token>#' \
  /var/www/html/MaarchCourrier/modules/visa/xml/remoteSignatoryBooks.xml
```

## End-to-end demo (100% UI + signature)

1. Log in as **`bblier` / `maarch`**.
2. **New mail** → fill the required fields → save / send to validation.
3. Tab **Attachments** → add a **PDF** of type **"Response project"**.
4. Tab **Visa circuit** → add a **Signer** (e.g. `bblier`, who has a real e-mail).
5. Basket **"Retours Courrier"** → open the mail → bottom action **"Send to NGSign"** →
   **Validate**. (~75 s: the NGSign sandbox is slow.)
6. The signer opens the NGSign e-mail, **places the signature** and signs.
7. Within **≤ 3 min** the cron retrieves the signed PDF: a **`signed_response`**
   attachment appears and the original moves to **SIGN**.

To force the retrieval immediately instead of waiting for the cron:
```bash
docker exec -u www-data maarch php \
  /var/www/html/MaarchCourrier/bin/signatureBook/process_mailsFromSignatoryBook.php \
  -c /var/www/html/MaarchCourrier/bin/signatureBook/ngsign-retrieve.config.json
```

## Stop / restart

```bash
docker compose -f maarch-ngsign-export/docker-compose.yml down   # stop (keeps data)
docker compose -f maarch-ngsign-export/docker-compose.yml up -d  # restart
```

## Notes / known points

- The signature label reads "iParapheur" only in internals — the visible UI shows
  **NGSign** (see Option A in `TECHNICAL_MANUAL.md`).
- The **NGSign sandbox is slow** (~80 s per upload) and requires the account's
  "transaction" feature enabled.
- The bundle's `docker-compose.yml` overrides the image entrypoint to (1) make the stock
  entrypoint idempotent on restart and (2) keep the docservers writable — do not remove
  those overrides.
