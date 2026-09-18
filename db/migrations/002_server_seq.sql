-- TRACE — server-assigned sync order, and a guard against stale pushes
--
-- Run after 001, then refresh the Data API schema cache — it does not notice a
-- new column on its own:
--   psql "$DATABASE_URL" -f db/migrations/002_server_seq.sql
--   neon data-api refresh-schema --database neondb
--
-- Why this exists. 001 pulled by `updated_at > cursor`, but `updated_at` is
-- written by the client when the user makes the edit. A device that edits
-- offline at 10:00 and syncs at 18:00 lands rows *behind* a cursor another
-- device already moved past at noon, and those rows were never pulled. Rows
-- sharing one timestamp (delete-all tombstones everything at the same instant)
-- could also fall between two pages.
--
-- The fix keeps the two jobs apart:
--   updated_at  client time, decides which edit wins (unchanged)
--   server_seq  server order, decides what a device has not seen yet
--
-- server_seq comes from one sequence, so it is unique — no ties, no page
-- boundary to fall through. Known limit: two transactions committing out of
-- order could still publish seq 101 before 100. With one user and a handful of
-- devices that needs two pushes racing to the millisecond; it is accepted
-- rather than paid for with a more elaborate scheme.
--
-- Safe to re-run.

begin;

create sequence if not exists trace_sync_seq as bigint;

-- A volatile default is evaluated per row, so existing rows are backfilled
-- with distinct values by the ADD COLUMN itself.
alter table projects add column if not exists server_seq bigint not null default nextval('trace_sync_seq');
alter table books    add column if not exists server_seq bigint not null default nextval('trace_sync_seq');
alter table entries  add column if not exists server_seq bigint not null default nextval('trace_sync_seq');
alter table notes    add column if not exists server_seq bigint not null default nextval('trace_sync_seq');
alter table proofs   add column if not exists server_seq bigint not null default nextval('trace_sync_seq');

-- Stamps every write with the next server_seq, and refuses to let an older
-- edit overwrite a newer one.
--
-- The push is a plain upsert, so without this last-write-wins held only on
-- pull: a device pushing a stale dirty row replaced the newer one on the
-- server. A stale update is not dropped silently, though. The stored row is
-- kept and re-stamped, which puts it back in front of every cursor — including
-- the pushing device's, which pulls it in the same sync and converges on it.
--
-- Stamping on INSERT as well means a client cannot choose its own server_seq.
create or replace function trace_sync_stamp() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.updated_at < old.updated_at then
    new := old;
  end if;
  new.server_seq := nextval('trace_sync_seq');
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['projects','books','entries','notes','proofs'] loop
    execute format('drop trigger if exists %I_sync_stamp on %I', t, t);
    execute format(
      'create trigger %I_sync_stamp before insert or update on %I
         for each row execute function trace_sync_stamp()', t, t);

    -- The pull is now (user_id, server_seq > cursor) ordered by server_seq.
    execute format('drop index if exists %I_sync_idx', t);
    execute format(
      'create index if not exists %I_seq_idx on %I (user_id, server_seq)', t, t);
  end loop;
end $$;

-- nextval runs as the caller, from both the column default and the trigger.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant usage on sequence trace_sync_seq to authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'anonymous') then
    revoke all on sequence trace_sync_seq from anonymous;
  end if;
end $$;

commit;
