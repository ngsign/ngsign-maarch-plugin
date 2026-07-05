# POC bundle

This folder holds the **ready-to-run demo instance** of the NGSign ↔ Maarch integration:

- `maarch-ngsign-export.tar.gz` — a full clone of a preconfigured Maarch Courrier 2301
  (app + PostgreSQL + docservers) with the NGSign connector already installed.

⚠️ The `.tar.gz` (~233 MB) exceeds GitHub's 100 MB limit and is **git-ignored**. Distribute
it as a **GitHub Release asset** or via **Git LFS**; it is not part of the committed tree.

👉 Full usage instructions: [`../docs/POC.md`](../docs/POC.md).

Quick start:
```bash
tar xzf maarch-ngsign-export.tar.gz
cd maarch-ngsign-export
./restore.sh
# then set your NGSign token — see ../docs/POC.md
```
Access: http://localhost:8081/maarch/dist/index.html (`bblier` / `maarch`).
