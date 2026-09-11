# TRACE — store listing

Copy for Google Play and the App Store. Written in the app's own voice: plain,
no superlatives, no promises about becoming more productive.

---

## Name

**TRACE**

Subtitle (App Store, 30 max): `Build. Read. Explore. Live.`

## Short description (Play, 80 max)

```
A quiet record of what you actually did. No streaks, no scores, no account.
```

(75 characters)

## Full description

```
Don't optimize your life. Remember it.

TRACE is a personal record of what you actually do — the code you wrote, the
pages you read, the rabbit holes you went down, and everything else. It is not
a habit tracker. There are no streaks to break, no badges, and no score.

Write what you did the way you would say it:

  "coded for 2 hours on my side project"
  "read 27 pages of The Design of Everyday Things"

TRACE turns that into an entry and asks you to confirm it. Most take under
five seconds.

FOUR CATEGORIES
Build — the things you make.
Read — books, with pages and progress.
Explore — research and curiosity, counted as time well spent.
Life — everything else.

LOOKING BACK
A timeline you can read months later. Projects that add up their own time.
A reading shelf with progress and the thoughts you kept. Insights that show
how many days you were present, not how many in a row.

ONE LINE
An optional sentence about the day. Never a prompt, never a journal.

YOURS
Everything is stored on your phone. No account is needed to use any part of
TRACE. Export your whole record as JSON or CSV at any time, or delete all of
it with one confirmation.
```

## Category

- Play: **Productivity**
- App Store: **Productivity** (secondary: **Lifestyle**)

## Keywords (App Store, 100 max)

```
journal,log,reading,books,time,tracker,diary,record,projects,coding,notebook,private,offline
```

## Content rating

Everyone / 4+. No user-generated content is shared, no web access, no purchases.

---

## Data safety

Answer according to how the build was produced. **The two builds give different
answers**, and filing the local-only answers for a sync-enabled build would be a
false declaration.

### Build without `--dart-define` backend URLs (default)

The sync screen is compiled out of view and there is no code path that sends
data off the device.

| Question                           | Answer |
| ---------------------------------- | ------ |
| Does the app collect user data?    | **No** |
| Does the app share user data?      | **No** |
| Is data encrypted in transit?      | Not applicable — nothing is transmitted |
| Can users request deletion?        | Yes — More → Export and delete → Delete all data |

Export uses the system share sheet. Where the file goes after that is the
user's choice and is not collection by the app.

### Build with sync configured

The data goes to a Neon project controlled by whoever built the app. For a store
release that is the developer, so it counts as collection.

| Data type                        | Collected | Shared | Optional | Purpose           |
| -------------------------------- | --------- | ------ | -------- | ----------------- |
| Email address                    | Yes       | No     | Yes      | Account management |
| Other user-generated content (entries, notes, books, projects) | Yes | No | Yes | App functionality (sync) |

- Encrypted in transit: **Yes** (HTTPS only).
- Optional: **Yes** — sync is off until the user signs in, and the app is fully
  usable without it.
- Deletion: **Yes** — Delete all data tombstones every row, pushes the deletion
  to the server, then erases the device copy.

## Privacy policy

Both stores require a URL. The text below is accurate for either build; host it
somewhere stable before submitting.

```
TRACE stores your entries, projects, books and notes on your device. It does
not use analytics, advertising, or crash reporting, and it does not contact
any server unless you turn on sync.

If you turn on sync, your email address and your record are stored in a
database used only to copy that record between your own devices. They are not
shared, sold, or used for anything else.

You can export everything at any time from More → Export and delete, and
delete everything from the same screen. Deleting while signed in removes the
server copy as well.
```

## Screenshots

Not yet taken — they need a device with a real week of entries, not seeded
demo data, or they will look like a template. Suggested set, in order:

1. Today, with four entries and a ONE LINE
2. Quick Add, mid-sentence, showing the parsed confirmation
3. Timeline, three days visible
4. Reading detail for a book in progress
5. Insights, consistency dots
