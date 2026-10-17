# Android offload utility — logbook

Resume point for the phone utility that offloads photos from the Fujifilm
X-E5 (via SD card reader / USB card-reader mode) to the Rails server.
Newest entries at the bottom of "Log". Update **Status** and **Next steps**
at the end of every session.

## Goal

An Android app that scans the camera's `DCIM` folder, uploads only files the
server doesn't have, remembers what it already offloaded, and survives
interruptions (app killed, network drop, card pulled). Shots land in the
existing unpublished review queue (`/:user_id/offloaded_photos`).

## Status

- [x] Server: `POST /offload_uploads` (upload, bearer token) — pre-existing, commit `fa161a4`
- [x] Server: `POST /offload_uploads/check` (checksum pre-check) — written, see Log 2026-10-17
- [x] Server: specs green (full suite 371 examples, 0 failures)
- [x] Decision: native Kotlin app (user confirmed 2026-10-17)
- [x] Decision: code lives in `android/` in this repo
- [ ] Android app v1
- [ ] Update `bin/upload_sd_card_photos` to the filename-based key (optional)

## Server API (what the app talks to)

Auth on both: `Authorization: Bearer $OFFLOAD_UPLOAD_TOKEN`. Server returns
503 if the token env var or the ingest owner (`FTP_INGEST_USER_EMAIL`) is not
configured, 401 on a bad token.

| Endpoint | Body | Responses |
|---|---|---|
| `POST /offload_uploads` | multipart `file` (`.jpg`/`.jpeg`/`.raf`) | `201 {status:"created", id}`; `200 {status:"duplicate"}`; `422 {errors}` (unsupported type etc — don't retry); `400` no file |
| `POST /offload_uploads/check` | JSON `{checksums: [base64 MD5, ...]}` (max 1000) | `200 {known: [...]}` — checksums the server already has (file or raw_file); `400` bad input |

Checksum format = Active Storage's: **base64-encoded MD5** of the file bytes.
A JPG and RAF with the same filename stem pair onto one Photo, in either order.

Server code: `OffloadUploadsController`, `OffloadUploadChecksController`,
`OffloadTokenAuthentication` (concern), `IngestOffloadedPhotoFile`,
`KnownPhotoChecksums`, `PhotoChecksumExists`.

## Design decisions

- **Fast "already offloaded" key = `folder/filename/size`**, stored in a local
  Room table. No hashing needed to skip known files, so rescanning a big card
  is instant. The user has X-E5 frame-number continuity enabled, so names
  don't repeat after formatting. Folder is part of the key because the
  counter wraps after 9999 and the camera rolls to a new folder
  (`100_FUJI`, `101_FUJI`). Size guards against a camera reset / second body
  reusing a name.
  - (The comment in `bin/upload_sd_card_photos` claiming the camera resets
    `DSCF####` after a format is wrong for this user's settings.)
- **Only new files get hashed** (MD5, base64) and sent to `/check`; the server
  checksum dedupe on upload remains the safety net.
- **Read the card via Storage Access Framework** (`ACTION_OPEN_DOCUMENT_TREE`,
  persisted permission) — no USB libraries needed.
- **Uploads via WorkManager**: network constraint, backoff retries, sequential,
  streamed from the content URI (RAFs are tens of MB), progress notification.
- **Result handling**: 201/duplicate → done; 422 → failed permanently;
  5xx/network → retry. Skip files whose size is still changing.
- **Secrets**: token in encrypted storage, HTTPS-only server URL.
- Resumable/chunked uploads deliberately skipped (files are 10–50 MB).

## Decisions (resolved)

- Native Kotlin app, in `android/` in this repo.
- Permanently deleted photos **should** be re-offloaded if the file shows up
  again (current server behavior: dedupe only against existing Photo records).

## Dev environment notes

- Working in GitHub Codespaces. Server work is fine there. Android emulator
  and USB/adb to a phone are **not** possible from a Codespace.
- Plan: write/unit-test Kotlin anywhere; for device testing use Android Studio
  on the user's computer (emulator/USB debugging/logcat), or CI-built APK
  sideloaded onto the phone as a fallback.
- Fresh Codespace: `bundle install` fails with `Bundler::PermissionError` on
  `/usr/local/bundle` until you run `sudo chown -R "$(id -u):$(id -g)" /usr/local/bundle`.

## Next steps

1. Scaffold the Android app in `android/`: folder picker → scanner → Room table → fake-server tests.
2. Upload worker, retries, notifications.
3. Settings screen (server URL + token), real-server test, install on phone.

## Log

### 2026-10-17
- Reviewed existing offload code: HTTPS endpoint (`fa161a4`) already does
  upload, JPG/RAF pairing and post-upload duplicate rejection.
- Planned the Android utility (see Design decisions). User corrected the
  assumption that the camera resets file numbering — they keep numbering
  continuous, so the local key is filename-based rather than content-hash.
- Added `POST /offload_uploads/check` + `KnownPhotoChecksums` query, extracted
  token auth into `OffloadTokenAuthentication`, wrote specs. Not yet run:
  `bundle install` was still in progress.
- Fixed bundler permissions (chown of /usr/local/bundle), `bundle install` OK,
  new specs + full suite green (371 examples).
- User decisions: Kotlin app, same repo (`android/`), deleted photos get re-offloaded. Server work committed.
