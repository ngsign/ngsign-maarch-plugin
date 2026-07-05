# NGSign connector for Maarch Courrier

Integrates **NGSign** (electronic signature) as an **external signatory book** in
**Maarch Courrier 2301**, through Maarch's native *external signatory book* framework.

Full cycle: send a document from Maarch → sign on NGSign → automatic retrieval of the
signed document and re-integration into Maarch.

## Package contents

```
ngsign-maarch-plugin/
├── README.md                         ← this file
├── LICENSE                           ← GNU GPL v3.0
├── connector/                        ← code to copy into Maarch (src/app/external/...)
│   └── src/app/external/externalSignatoryBook/ngsign/
│       ├── controllers/NgsignController.php
│       └── Infrastructure/NgsignClient.php
├── config/
│   ├── remoteSignatoryBooks.iparapheur-slot.sample.xml   ← Option A (no rebuild)
│   └── remoteSignatoryBooks.ngsign-native.sample.xml     ← Option B (native)
├── sql/001_ngsign_transactions.sql   ← tracking table (optional)
├── lang/lang-{fr,en}.json            ← "NGSign" UI labels
├── batch/ngsign-retrieve.config.sample.json  ← retrieval cron config
├── poc/                             ← ready-to-run demo instance (release asset)
│   └── README.md                    ← the .tar.gz bundle is git-ignored (~233 MB)
└── docs/
    ├── TECHNICAL_MANUAL.md           ← architecture, API, options, limitations
    ├── INSTALLATION.md               ← step-by-step procedure (WITHOUT Docker)
    ├── PATCHES.md                    ← exact edits of the 2 core files
    └── POC.md                        ← how to run & demo the POC instance
```

## Quick start

1. Read **`docs/TECHNICAL_MANUAL.md`** (understand the architecture and choose option A or B).
2. Follow **`docs/INSTALLATION.md`** (install on your Maarch instance).
3. Apply the 2 patches described in **`docs/PATCHES.md`**.

## Try it — POC / demo instance

Don't want to install anything? A **ready-to-run, preconfigured Maarch + NGSign Docker
instance** is provided in [`poc/`](poc/) to demo the full signature cycle in minutes:

```bash
cd poc
tar xzf maarch-ngsign-export.tar.gz && cd maarch-ngsign-export
./restore.sh                     # recreates the stack
# set your NGSign token (see docs/POC.md), then open:
# http://localhost:8081/maarch/dist/index.html   (bblier / maarch)
```

Full guide: **[`docs/POC.md`](docs/POC.md)**.
The bundle (~233 MB) is distributed as a **release asset** (too large for git).

## The only 2 external settings

In `modules/visa/xml/remoteSignatoryBooks.xml`:
- `<url>` — NGSign server URL,
- `<token>` — API token (Bearer).

Everything else (signature position, send mode, statuses…) has sensible defaults and
remains adjustable in the same file.

## Status

Functional POC, validated end to end. See `docs/TECHNICAL_MANUAL.md` §9 (limitations) and
§10 (what was validated) for the productization roadmap.

## Requirements

Maarch Courrier 2301 · PHP 8.1 + ext-cURL · PostgreSQL · an NGSign account with an API
token and the "transaction" feature enabled.

## License

**GNU General Public License v3.0** (see `LICENSE`).

This plugin integrates with Maarch Courrier, itself distributed under **GPLv3**: it
extends its classes and runs inside its process (a derivative work). GPLv3 is therefore
the coherent, compatible choice.

Copyright © 2026 NG Technologies. This program is free software: you can redistribute it
and/or modify it under the terms of the GNU General Public License version 3 as published
by the Free Software Foundation.
