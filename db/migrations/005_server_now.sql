-- TRACE — the server's clock, for clamping skewed device clocks
--
-- Run after 004, then refresh the Data API schema cache:
--   psql "$DATABASE_URL" -f db/migrations/005_server_now.sql
--   neon data-api refresh-schema --database neondb
--
-- Last-write-wins trusts each device's clock. A phone set a day ahead would win
-- every conflict for a day. Before pushing, the app asks this function for the
-- time and clamps any `updated_at` more than five minutes past it
-- (Conflict.clampToServer). A build that finds the function missing syncs
-- without clamping, so this can be applied at any point.
--
-- Safe to re-run.

begin;

create or replace function public.server_now() returns timestamptz
language sql stable as $$ select now() $$;

-- Functions are executable by PUBLIC by default; narrow it to signed-in users
-- like everything else here.
revoke all on function public.server_now() from public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.server_now() to authenticated;
  end if;
end $$;

commit;
