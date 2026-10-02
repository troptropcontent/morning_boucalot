# FTP photo offload — logbook

Goal: the Fujifilm X-E5 pushes shots over FTP straight to the server. They
land in an "Offloaded Photos" review queue (not the main gallery) where you
Publish or Discard each one — including pairing a JPEG with its RAF raw
counterpart when the camera sends both.

## Status: app code done, infra setup not done yet

All Rails-side code is written, tested, and merged into this branch.
What's left is one-time server/camera setup — see the checklist at the
bottom.

## Decisions made (and why)

- **Reuse `Photo` with a `published` boolean**, not a separate
  `OffloadedPhoto` model. Reuses the existing EXIF pipeline, variants, and
  delete logic as-is. Main gallery scopes to `published: true`; the review
  queue scopes to `published: false`.
- **Both JPEG and RAF are ingested.** `Photo` gained `has_one_attached
  :raw_file` alongside the existing `:file`. The two are paired by
  filename stem (`DSCF1234.JPG` + `DSCF1234.RAF`) regardless of which
  arrives first — see `IngestOffloadedPhotoJob`.
- **Polling, not a webhook.** First pass had the FTP server call a Rails
  webhook the instant a transfer finished. Dropped it: `ScanFtpIncomingJob`
  just checks the incoming folder every minute (via
  `config/recurring.yml`) and ingests anything whose mtime is more than 10
  seconds old (cheap guard against reading a half-written upload). Simpler
  — no webhook endpoint, no shared secret, no upload-script wiring.
- **vsftpd installed directly on the VPS, not via Docker.** Considered a
  Kamal accessory running a pure-ftpd Docker image, but FTP passive mode
  needs the server to advertise its real public IP for the data
  connection — fragile when the FTP server sits behind Docker's own NAT.
  Running vsftpd straight on the host sidesteps that entirely. To keep
  this from being untracked manual steps, it's scripted and committed:
  `config/vsftpd.conf` (template) + `bin/setup_ftp_server` (idempotent
  setup script, run once per VPS as root).
- **FTPES (explicit TLS) kept**, not plain FTP — the VPS is on the public
  internet, so the camera's login shouldn't travel in clear text.

## Where things live

- `app/models/photo.rb` — `published`/`unpublished` scopes, `raw_file`
  attachment, relaxed validation (file OR raw_file required)
- `app/jobs/scan_ftp_incoming_job.rb` — polls the incoming folder
- `app/jobs/ingest_offloaded_photo_job.rb` — pairs JPEG/RAF, dedupes,
  creates/updates the `Photo` row
- `app/queries/photo_checksum_exists.rb` — shared dedup check (also used
  by `UploadPhoto` now)
- `app/controllers/offloaded_photos_controller.rb` +
  `app/views/offloaded_photos/` — the review queue UI (publish/discard)
- `app/services/publish_offloaded_photo.rb` — flips `published: true`
  (discard reuses the existing `DeletePhoto` service)
- `config/vsftpd.conf`, `bin/setup_ftp_server` — the FTP server itself
- `config/deploy.yml` — bind-mounts the host folder vsftpd writes into,
  into the app containers; has a comment block with the remaining
  checklist too
- `config/recurring.yml` — schedules `ScanFtpIncomingJob` every minute

Tests: model/job/service/controller specs throughout `spec/`, all passing
(298 examples at time of writing).

## What's left — do this fresh, not tired, one step at a time

1. Get a TLS cert onto the VPS (for FTPES) — not automatable from here,
   depends on your DNS/registrar setup.
2. Run `bin/setup_ftp_server` on the VPS as root, with the env vars listed
   in its header (`FTP_SYSTEM_USER`, `FTP_SYSTEM_PASSWORD`,
   `FTP_INCOMING_DIR`, `SSL_CERT_FILE`, `SSL_KEY_FILE`). Installs vsftpd,
   creates the camera's login, writes the config, starts the service.
3. Open port 21 and the passive port range (default 30000-30009) in the
   VPS firewall.
4. Export `FTP_INGEST_USER_EMAIL` (your member account's email — who
   offloaded photos get attributed to) and deploy via Kamal.
5. Point the X-E5's FTP transfer settings at the server: host, port,
   FTPES, and the username/password from step 2.

Re-run `bin/setup_ftp_server` any time `config/vsftpd.conf` changes, or if
the VPS ever gets rebuilt from scratch — it's idempotent.
