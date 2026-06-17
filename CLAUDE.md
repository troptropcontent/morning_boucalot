A personal webapp to store and manage photos taken with my camera.

Build it as if it will be used by millions, even though it's a solo app for now.

## Stack

- Rails 8.1, fullstack (no separate API or React frontend)
- Rspec for tests
- Tailwind CSS + DaisyUI for styling
- Hotwire (Turbo + Stimulus) for reactivity
- SQLite in development, Postgres in production
- Rails built-in authentication (no Devise)
- Active Storage for photo uploads (local disk in dev, S3 in prod)

## Commands

```bash
bin/dev                  # start dev server (Rails + Tailwind watcher)
bin/rails db:migrate     # run pending migrations
bin/rails db:reset       # drop, create, migrate, seed
bundle exec rspec        # run tests
```

## Data model

### User
- `email_address:string`, `password_digest:string`
- Has many `photos`
- Has many `sessions` (Rails built-in auth)

### Photo
- `user:references`, `title:string`, `description:text`
- `taken_at:datetime`, `camera_model:string`
- `focal_length:decimal(8,2)`, `aperture:decimal(5,2)`, `iso:integer`, `shutter_speed:string`
- `width:integer`, `height:integer`, `file_size:integer`
- `has_one_attached :file` — **attach before save**: `validates :file, presence: true` means `build` + `attach` + `save!` is required; `create!` then `attach` will fail validation

### Active Storage
- Variants defined on Photo: `thumbnail` (300×300 fill), `medium` (800×600 limit), `large` (2400×2400 limit)

## Features

### Photos
- Upload, view, edit, delete photos
- Store EXIF metadata (date taken, camera model, focal length)

## Design

- **Mobile-first**: the primary device is a phone. Design for small screens first, enhance for larger ones.
- Touch targets should be large enough to tap comfortably.
- Avoid hover-only interactions for core functionality.

## Conventions

- Prefer Turbo Frames and Turbo Streams over full-page renders for CRUD actions
- Stimulus controllers for any JS behavior; avoid inline JS
- Apply the clean architecture as luch as possible, put all the business logic inside services
- Test coverage must be close to 100%
