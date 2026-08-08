# Frontend component — NGSign (Option B only)

Angular part of **Option B** (native `ngsign` id). **Not needed for Option A** (which
reuses the generic iParapheur dialog and requires no rebuild).

| File | Role |
|---|---|
| `ngsign.component.ts` | Send-dialog component (`app-ngsign`, `NgsignComponent`). Faithful copy of Maarch's `i-paraph` — same public contract. |
| `ngsign.component.html` | Minimal template (uses the `lang.sentToNgsign` label). |
| `ngsign.component.scss` | Same style as `i-paraph`. |

**Verified on Maarch Courrier 2301**: these files build cleanly and the component is
present in the compiled bundle.

## How to integrate

- **Wiring** (4 edits): `docs/INSTALLATION.md` — **Step 5-bis**.
- **Full reproducible build & deploy** (clone → edit → `ng build` in a `node:20`
  container → `docker cp dist/`): `docs/OPTION_B_FRONTEND_TEST.md`.

Copy these three files into
`src/frontend/app/actions/send-external-signatory-book-action/ngsign/`, then do the 3
one-line wirings (module declaration, `@ViewChild('ngsign')`, `<app-ngsign #ngsign …>`
template element) and rebuild.

> The parent action dispatches dynamically via
> `this[authService.externalSignatoryBook.id]`, so **no change** to `executeAction()` /
> `isValidAction()` is required — only the `@ViewChild` ref named exactly `ngsign`.
