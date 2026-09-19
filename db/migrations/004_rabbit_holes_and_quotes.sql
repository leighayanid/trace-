-- TRACE — rabbit holes and quote pages
--
-- Run after 003, then refresh the Data API schema cache:
--   psql "$DATABASE_URL" -f db/migrations/004_rabbit_holes_and_quotes.sql
--   neon data-api refresh-schema --database neondb
--
-- Two nullable columns. Builds from before this migration keep working: they
-- neither send nor read them. Builds after it send them, so run this first.
--
-- Safe to re-run.

begin;

-- The EXPLORE entry this one led on from. Deliberately no foreign key: a push
-- is batched, so a child can reach the server a request before its parent,
-- and a reference to a deleted entry just ends the chain.
alter table entries add column if not exists parent_id uuid;

create index if not exists entries_parent_idx on entries (parent_id)
  where parent_id is not null;

-- The page a quote is on.
alter table notes add column if not exists page integer
  check (page is null or page > 0);

commit;
