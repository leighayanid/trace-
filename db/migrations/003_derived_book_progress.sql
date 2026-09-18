-- TRACE — reading progress is derived, not stored
--
-- Run after 002, then refresh the Data API schema cache:
--   psql "$DATABASE_URL" -f db/migrations/003_derived_book_progress.sql
--   neon data-api refresh-schema --database neondb
--
-- books.current_page was a running total that every session incremented. It
-- disagreed with the sessions as soon as one was deleted or edited, never moved
-- for pages typed into Quick Add, and lost an increment whenever two devices
-- logged reading offline — last-write-wins keeps one book row, not both sums.
--
-- The app now derives the page from the book's live READ sessions (entries
-- with quantity_unit = 'pages'), so the column has nothing left to say.
--
-- Builds from before this migration still send current_page and will fail to
-- push books until they are updated. Update every device, then run this.
--
-- Safe to re-run.

begin;

alter table books drop column if exists current_page;

commit;
