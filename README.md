# PFA Pharmacy Invoice Tracker

A free, **offline** desktop app (Windows) for tracking the invoices you owe
your medicine suppliers and distributors. Everything is stored locally on
this PC — nothing is uploaded anywhere.

Built as a full replacement for tracking the XLSX supplier invoice sheet.

## Features

- **Supplier catalog** — keep name, phone and location for every distributor.
- **Invoice tracking** — record supplier invoice number, Ref/PO, description,
  invoice / received / due dates, amount, tax %, partial payments and the
  payment method (Cash, Bank Pay, Cheque, MoMo, Card).
- **Status awareness** — every invoice shows as **Open**, **Partially Paid**,
  **Overdue** or **Paid**, with overdue rows highlighted in red.
- **Per-supplier filter & summary** — filter by supplier and see what you
  owe, overdue amount and how many invoices are unpaid.
- **Receipt attachments** — attach photos or scanned images of delivery
  receipts to an invoice and view them later.
- **CSV export** — export invoices (with computed totals/balance/status) or
  the supplier list to CSV that opens directly in Excel.
- **ZIP backup** — export everything (data + receipts) to one file, and
  restore it later. Restore always makes a safety backup of your current
  data first.
- **Self-updating** — "Check for updates" downloads the newest version from
  GitHub and restarts the app automatically.

## Install

1. Go to **Releases** on this repository.
2. Download `PFA-Pharmacy-Invoice-Tracker.zip` (the newest version).
3. Extract it to a folder on your PC — **not** inside `C:\Program Files`
   (the app needs to update itself).
4. Run `PFA-Pharmacy-Invoice-Tracker.exe`.

No internet connection is required after download. All data (invoices,
suppliers, receipts) lives in the app's local data folder on this PC.

## Updating

In the app, open the ⋮ (More) menu → **Check for updates**. If a newer
version is available it is downloaded and installed automatically, then the
app restarts on the new version. Releases are published manually from this
repository.

## Backup & restore (recommended)

Use the ⋮ (More) menu regularly:

- **Export backup (ZIP)** → saves your data + receipts to one file.
- **Restore backup…** → replaces current data with a backup (a safety backup
  is saved automatically first).
- **Export CSV • Invoices** / **Export CSV • Suppliers** → open in Excel.

## Data & privacy

- No accounts, no cloud, no tracking.
- Data is kept in the OS user data folder for this app on the PC where it
  runs.
- To move to another PC, use **Export backup (ZIP)** on the old PC and
  **Restore backup…** on the new one.

## Development

This is a Flutter app. Requirements: Flutter stable (Dart SDK 3.5+).

```sh
flutter pub get
flutter create --platforms=windows --org com.pfa --project-name pfa_pharmacy_invoice_tracker .
flutter analyze --no-fatal-infos
flutter test
flutter build windows --release    # output in build/windows/x64/runner/Release
```

CI (`.github/workflows/ci.yml`):

- Every push to `main` runs analyze + tests, builds the Windows release, and
  uploads it as a rolling GitHub Release tagged `v<pubspec version>`.
- Releases are created **manually** by bumping `version:` in `pubspec.yaml`
  and pushing to `main`. The app's update check compares against the latest
  GitHub release tag.

## License

Private/internal use for PFA Pharmacy.