# FTP photo offload — logbook

Goal: the Fujifilm X-E5 pushes shots over FTP straight to the server. They
land in an "Offloaded Photos" review queue (not the main gallery) where you
Publish or Discard each one — including pairing a JPEG with its RAF raw
counterpart when the camera sends both.

## Status (as of 2026-10-02 night): FTP server fully working, app pickup unverified

All Rails-side code is written, tested, and merged into `main` (commit
`5902ebe`). The VPS-side FTP server is now **fully set up and verified
working end-to-end** — TLS handshake, login, and passive-mode file
transfer all succeeded from a real client (`curl`). What's unverified is
the *last* link: whether `ScanFtpIncomingJob` actually picks the
uploaded file up and creates an unpublished `Photo`. A manual JPEG
upload via `curl` didn't show up in the Offloaded Photos page after
~1 minute — this is the next thing to debug, not a re-run of the setup
below.

### Where we left off / next steps for tomorrow

1. **Check the job actually ran.** `docker logs` on the job container
   returns nothing — confirmed this is expected, not a symptom: this app
   only logs to stdout when `RAILS_LOG_TO_STDOUT` is set
   (`config/environments/production.rb:101`), and `deploy.yml` doesn't
   set it. Rails is logging to a file inside the container instead. Read
   that file directly:
   ```bash
   docker exec $(docker ps --filter "name=morning-boucalot-job" --format '{{.Names}}' | head -1) tail -n 100 log/production.log
   ```
   Look for `ScanFtpIncomingJob` or `IngestOffloadedPhotoJob` entries, or
   errors. If nothing shows up at all, the recurring schedule may not be
   running (see #2). If it ran but errored, the error should point at the
   bug directly.
2. **Sanity-check the recurring scheduler is even active in production.**
   `config/recurring.yml` only defines the `scan_ftp_incoming` entry under
   the `production:` key — confirm the job container is actually running
   with Solid Queue's recurring scheduler enabled (check `bin/jobs` /
   however the `job` service is started — see `config/deploy.yml`
   `servers.job.cmd`). It's possible the schedule config needs the app
   restarted/redeployed again to pick up, or there's a puma/solid_queue
   plugin flag we're missing for recurring tasks in this app's setup.
3. **Confirm the uploaded file is actually sitting in the shared
   folder**, from inside the container (not just on the host):
   ```bash
   docker exec $(docker ps --filter "name=morning-boucalot-web" --format '{{.Names}}' | head -1) ls -la /data/ftp_incoming
   ```
   If the file ISN'T visible here even though `ls /srv/ftp_incoming` on
   the host shows it, the bind-mount path in `config/deploy.yml` doesn't
   actually match what's running (e.g. old container, stale mount) — a
   path/deploy mismatch, not a job bug.
4. **Check `FTP_INCOMING_DIR` is actually set inside the container**
   (it's a `clear` env var in `deploy.yml`, should always be there, but
   worth confirming nothing dropped it):
   ```bash
   docker exec $(docker ps --filter "name=morning-boucalot-job" --format '{{.Names}}' | head -1) env | grep FTP
   ```
5. Once the pairing/ingest job is confirmed working on a plain JPEG,
   re-test with a same-stem JPEG+RAF pair to confirm the pairing logic,
   then finally test with the actual camera.

### Infra gotchas hit and fixed tonight (useful if re-running setup elsewhere)

- `PRODUCTION_APP_HOST` was stale in the deploy shell and pointed Kamal's
  proxy at the wrong domain (`thepocman.com` instead of
  `morningboucalot.com`) — caused `ERR_SSL_PROTOCOL_ERROR` on the main
  site right after deploying. Fixed by re-exporting the correct value and
  redeploying. **Always double check `echo $PRODUCTION_APP_HOST` before
  deploying** if multiple projects share a shell/VPS.
- `sudo -E` is not supported by this VPS's sudo build — use
  `sudo env VAR=val ... command` instead to pass env vars through sudo.
- `curl -s https://ifconfig.me` returned an IPv6 address by default,
  which broke passive-mode (vsftpd.conf has `listen_ipv6=NO`). Fixed in
  `bin/setup_ftp_server` by forcing `curl -4`.
- `ssl_tlsv1_2=YES` in vsftpd.conf isn't a recognized directive on this
  vsftpd build (3.0.5) — made vsftpd fail to start entirely
  (`exit-code 2/INVALIDARGUMENT`). Removed; `ssl_enable=YES` alone is
  enough, confirmed TLSv1.3 negotiates fine without it.
- vsftpd returned `530 Login incorrect` for a correct password — turned
  out to be `/etc/pam.d/vsftpd`'s `pam_shells.so` rejecting the FTP
  user's intentionally-restricted `/usr/sbin/nologin` shell, because that
  shell isn't listed in `/etc/shells`. Fixed by appending it:
  `echo "/usr/sbin/nologin" | sudo tee -a /etc/shells`. This is a
  standard Debian/Ubuntu vsftpd gotcha, not specific to this setup — if
  the FTP user's shell is ever changed, check `/etc/shells` again.
- **Found 2026-10-04**: `IngestOffloadedPhotoJob` failed on every real
  photo with `Errno::EACCES (Permission denied @ rb_sysopen -
  /data/ftp_incoming/DSCF0001.JPG)` — `ScanFtpIncomingJob` *was* finding
  and enqueuing files correctly, so the "app pickup unverified" status
  above was actually this, not a scan/scheduling problem. Root cause:
  vsftpd's default `local_umask` (077) writes uploads as `rw-------`,
  owned by `ftpcam` — unreadable by the Rails job container, which reads
  the same bind-mounted folder as a different user (`rails`,
  uid/gid 1000). Fixed without making files world-readable: the setup
  script now group-owns the incoming dir by `FTP_READ_GID` (default
  1000, matching the `rails` group in `Dockerfile`) with the setgid bit,
  so uploads inherit that group automatically; `local_umask=027` in
  `config/vsftpd.conf` gives the group read access (mode 640 on files,
  2770 on the dir — group also needs dir write+execute for
  `IngestOffloadedPhotoJob`'s `File.delete` cleanup, since unlink
  permission comes from the directory, not the file). Re-run
  `bin/setup_ftp_server` on the VPS to apply — it fixes permissions on
  already-uploaded files too, not just new ones.

These fixes are applied on the live VPS already. The `ssl_tlsv1_2` and
`curl -4` fixes are also applied in this repo's `config/vsftpd.conf` /
`bin/setup_ftp_server` (uncommitted as of this logbook entry — check
`git status` before assuming they're committed). The PAM `/etc/shells`
fix and the `sudo env` workaround are VPS-only, nothing to change in the
repo for those.

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
