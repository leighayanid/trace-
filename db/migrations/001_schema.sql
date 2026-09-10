-- TRACE — Neon Postgres schema
--
-- Mirrors the Drift schema in lib/core/database/tables.dart, plus user_id,
-- minus the local-only sync bookkeeping (dirty, synced_at) which never leaves
-- the device.
--
-- Run against a Neon branch:
--   psql "$DATABASE_URL" -f db/migrations/001_schema.sql
--
-- TRACE has one user. RLS is still mandatory: the Data API endpoint is public
-- on the internet, and the policy is what makes a stolen or expired token
-- useless. Single-user means less UI, not less security.

begin;

-- Provides auth.user_id(), which reads the `sub` claim from the validated JWT.
create extension if not exists pg_session_jwt;

-- ── Tables ──────────────────────────────────────────────────────────────────

create table if not exists projects (
  id            uuid primary key,
  user_id       uuid not null default auth.user_id(),
  name          text not null,
  description   text,
  status        text not null default 'active'
                  check (status in ('active','paused','done','archived')),
  target_secs   integer check (target_secs is null or target_secs > 0),
  started_at    timestamptz,
  ended_at      timestamptz,
  created_at    timestamptz not null,
  -- Client-supplied, never overwritten by a trigger. Last-write-wins needs this
  -- to mean "when the user made the edit", not "when the row reached Postgres".
  updated_at    timestamptz not null,
  deleted_at    timestamptz
);

create table if not exists books (
  id            uuid primary key,
  user_id       uuid not null default auth.user_id(),
  title         text not null,
  author        text,
  cover_path    text,
  current_page  integer not null default 0 check (current_page >= 0),
  total_pages   integer check (total_pages is null or total_pages > 0),
  status        text not null default 'reading'
                  check (status in ('want','reading','finished','abandoned')),
  started_at    timestamptz,
  finished_at   timestamptz,
  created_at    timestamptz not null,
  updated_at    timestamptz not null,
  deleted_at    timestamptz
);

create table if not exists entries (
  id            uuid primary key,
  user_id       uuid not null default auth.user_id(),
  category      text not null
                  check (category in ('build','read','explore','life')),
  title         text not null,
  description   text,
  date          date not null,
  started_at    timestamptz,
  ended_at      timestamptz,
  duration_secs integer check (duration_secs is null or duration_secs >= 0),
  quantity      numeric,
  quantity_unit text,
  -- Deliberately ON DELETE SET NULL, not CASCADE: losing a project must never
  -- destroy the record of time spent on it.
  project_id    uuid references projects(id) on delete set null,
  book_id       uuid references books(id) on delete set null,
  tags          jsonb not null default '[]',
  created_at    timestamptz not null,
  updated_at    timestamptz not null,
  deleted_at    timestamptz
);

create table if not exists notes (
  id            uuid primary key,
  user_id       uuid not null default auth.user_id(),
  body          text not null,
  kind          text not null default 'note'
                  check (kind in ('one_line','thought','quote','note')),
  date          date,
  entry_id      uuid references entries(id) on delete cascade,
  project_id    uuid references projects(id) on delete cascade,
  book_id       uuid references books(id) on delete cascade,
  created_at    timestamptz not null,
  updated_at    timestamptz not null,
  deleted_at    timestamptz
);

create table if not exists proofs (
  id            uuid primary key,
  user_id       uuid not null default auth.user_id(),
  entry_id      uuid not null references entries(id) on delete cascade,
  kind          text not null
                  check (kind in ('git','screenshot','note','link','file')),
  label         text,
  uri           text,
  created_at    timestamptz not null,
  updated_at    timestamptz not null,
  deleted_at    timestamptz
);

-- ── Indexes ─────────────────────────────────────────────────────────────────

-- The sync pull is always (user_id, updated_at > cursor) ordered by updated_at.
create index if not exists entries_sync_idx  on entries  (user_id, updated_at);
create index if not exists projects_sync_idx on projects (user_id, updated_at);
create index if not exists books_sync_idx    on books    (user_id, updated_at);
create index if not exists notes_sync_idx    on notes    (user_id, updated_at);
create index if not exists proofs_sync_idx   on proofs   (user_id, updated_at);

-- Reads are day-ordered.
create index if not exists entries_date_idx    on entries (user_id, date desc);
create index if not exists entries_project_idx on entries (project_id)
  where project_id is not null;
create index if not exists entries_book_idx    on entries (book_id)
  where book_id is not null;

-- ── Row Level Security ──────────────────────────────────────────────────────
--
-- Both USING and WITH CHECK are required. USING alone filters reads while still
-- permitting an insert that forges another user's user_id.

alter table projects enable row level security;
alter table books    enable row level security;
alter table entries  enable row level security;
alter table notes    enable row level security;
alter table proofs   enable row level security;

-- Belt and braces: policies apply to the table owner too, so a mistake in role
-- configuration cannot silently expose everything.
alter table projects force row level security;
alter table books    force row level security;
alter table entries  force row level security;
alter table notes    force row level security;
alter table proofs   force row level security;

do $$
declare t text;
begin
  foreach t in array array['projects','books','entries','notes','proofs'] loop
    execute format('drop policy if exists %I_owner on %I', t, t);
    execute format($f$
      create policy %I_owner on %I
        for all
        using      (user_id = auth.user_id())
        with check  (user_id = auth.user_id())
    $f$, t, t);
  end loop;
end $$;

-- ── Grants ──────────────────────────────────────────────────────────────────
--
-- The Data API maps a JWT to a Postgres role. Confirm the exact role name for
-- this project before relying on the block below:
--     neon data-api get
-- and read `settings.db_anon_role`. Rows stay protected by RLS regardless; a
-- grant only decides who may attempt a query at all.

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant usage on schema public to authenticated;
    grant select, insert, update, delete
      on projects, books, entries, notes, proofs
      to authenticated;
  end if;
end $$;

-- The anonymous role must never reach this data. TRACE has no public surface.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anonymous') then
    revoke all on projects, books, entries, notes, proofs from anonymous;
  end if;
end $$;

commit;
