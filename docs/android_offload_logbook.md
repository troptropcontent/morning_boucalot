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
- [x] Android app scaffold in `android/` (committed `2bbc05d`)
- [x] Upload worker (`UploadPending` + `UploadWorker`/`UploadScheduler`), settings screen, encrypted token — compiles, 39 JVM unit tests green, lint has no errors, debug APK builds. **Not committed yet.**
- [ ] First on-device test (folder picker with the real card reader, foreground notification, Wi-Fi constraint)
- [ ] First run against the real server (only tested against MockWebServer + the Rails request specs)
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

### Android toolchain in a fresh Codespace (not persisted across rebuilds)

```bash
sudo apt-get update && sudo apt-get install -y openjdk-21-jdk-headless unzip   # trixie has no JDK 17; 21 works
mkdir -p ~/android-sdk/cmdline-tools && cd ~/android-sdk/cmdline-tools
curl -fsSLO https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q commandlinetools-*.zip && mv cmdline-tools latest && rm commandlinetools-*.zip
yes | ~/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses
~/android-sdk/cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"
echo "sdk.dir=$HOME/android-sdk" > android/local.properties   # gitignored
```

Then `cd android && ./gradlew testDebugUnitTest assembleDebug`. The APK lands in
`android/app/build/outputs/apk/debug/app-debug.apk`. First build ~1 min after
the Gradle download. The Gradle wrapper (8.9) is committed.

## Next steps

1. Commit the upload worker work.
2. Sideload `android/app/build/outputs/apk/debug/app-debug.apk` on the phone; try: pick DCIM on the card, enter server URL + `OFFLOAD_UPLOAD_TOKEN`, scan & upload a few shots. Check they appear in the review queue, and that a second scan queues nothing.
3. Fix whatever the device turns up. Likely suspects: SAF listing speed on a big card, the notification permission flow, Wi-Fi-only constraint behaviour.
4. Polish: app icon, a "failed files" list with per-file retry, completion notification, files deleted from the card staying PENDING forever, two-scan size-stability check, instrumented tests, coverage tooling for the JVM tests.

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

### 2026-10-17 (later)
- Scaffolded `android/` (package `com.morningboucalot.offload`): version catalog
  (AGP 8.7.3, Kotlin 2.0.21, Room 2.6.1, OkHttp 4.12.0, Compose BOM 2024.10.01),
  `core/` (CardFile key, ScanPlanner, UploadOutcome, Checksums, OffloadApi),
  `data/` (Room entity/DAO/db), `scan/` (ScanCard, CardScanner via SAF),
  `ui/MainActivity` (pick folder, scan, per-status counts), JVM unit tests
  incl. MockWebServer tests of the API client.
- **Not compiled or run**: no JDK, Gradle or Android SDK here, and no Gradle
  wrapper (gradlew + jar) yet. Dependency versions are from memory — bump if
  resolution complains.
- Known gaps: no upload worker, no settings screen (server URL/token), stability
  check is mtime-based only, no instrumented tests.

### 2026-10-17 (toolchain)
- Installed JDK 21, Android cmdline-tools, platform 35, build-tools 35.0.0 (SDK
  licenses accepted on the user's behalf as part of the install), generated
  the Gradle 8.9 wrapper. First compile worked with the from-memory versions.
- One test failed on first run — a test bug (fake clock of 42ms made the file
  look freshly written), not an app bug. Fixed. 22/22 green; `assembleDebug` OK.
- Not yet run on a device or emulator.

### 2026-10-17 (upload worker)
- `upload/UploadPending`: batches of 20 → hash (MD5 b64) → `/check` → mark known
  as DONE → upload the rest sequentially, writing each state change to Room.
  Stops (rows stay PENDING) on AUTH (bad token), NETWORK, CARD_UNAVAILABLE
  (unreadable card / revoked permission, doesn't burn attempts). A file hitting
  retryable errors 5 times is parked FAILED so it can't block the queue.
  Rows left UPLOADING by a killed run are reset to PENDING on the next run.
- `UploadWorker` (WorkManager, foreground service type dataSync, progress
  notification) maps stop reasons to Result.retry (network, exponential
  backoff from 30s) / failure (auth) / success (card gone, nothing more to do).
  `UploadScheduler` uses unique work `offload-upload` with KEEP, constraint
  UNMETERED (Wi-Fi only, default on) or CONNECTED.
- `settings/`: `Settings` (SharedPreferences) + `SecretBox` (token encrypted with
  an AES-GCM key in the Android Keystore; undecryptable → user is asked again).
  Server URL must be https. `SecretBox` and the worker/UI shell are the
  parts with no unit tests (need a device).
- UI: folder picker, URL/token fields, Wi-Fi switch, "Scan card & upload",
  "Retry pending uploads", per-status counts.
- Lint: no errors; warnings only (missing icon, outdated deps, backup rules).
