# CLAUDE.md --- TRACE

## Project Overview

TRACE is a minimalist personal habit/life tracker built around one idea:

> **Don't optimize your life. Remember it.**

TRACE is not intended to be another gamified habit tracker. It is a
quiet personal record of what the user actually does, with a strong
focus on:

-   Coding and building things
-   Reading books
-   Exploring the web and learning through rabbit holes
-   Everyday life
-   Reflection without forced journaling
-   Long-term patterns rather than streak anxiety

Core tagline:

> **Build. Read. Explore. Live.**

The product should feel like a beautifully designed digital notebook
made for a developer, reader, and curious internet user.

------------------------------------------------------------------------

## Product Philosophy

### 1. The day is the primary unit

Do not make habits the center of the product.

The fundamental question is:

> "What did I do today that mattered to me?"

A day can contain multiple entries.

### 2. Entries are more important than checkboxes

Avoid the traditional:

-   [x] Read
-   [x] Code
-   [ ] Exercise

Instead, record meaningful activity:

-   2h 34m --- Build --- PDS Express
-   32 pages --- Read --- The Design of Everyday Things
-   41m --- Explore --- Cloudflare Durable Objects
-   28m --- Life --- Walk

### 3. No productivity theater

Avoid:

-   Excessive gamification
-   Confetti
-   Badges everywhere
-   Aggressive streak mechanics
-   "You're better than 87% of users" messaging
-   Motivational quotes
-   Artificial urgency
-   Excessive notifications
-   Bright dashboards

TRACE should feel calm, private, intelligent, and sophisticated.

### 4. Consistency is a pattern, not a competition

Missing a day should never feel like failure.

Prefer:

> 18 of 22 days

over:

> 🔥 18-day streak

### 5. Capture should be extremely fast

The user should be able to record something in seconds.

Natural-language entry is a core interaction:

> "coded for 2 hours on PDS Express"

can become:

``` text
BUILD
PDS Express
2h
```

Likewise:

> "read 27 pages of Atomic Habits"

becomes:

``` text
READ
Atomic Habits
27 pages
```

------------------------------------------------------------------------

# Core Categories

TRACE has four primary categories.

## BUILD

Things the user creates or works on.

Examples:

-   Coding
-   Side projects
-   Work
-   Writing
-   Learning by building
-   Design
-   Research implementation

## READ

Intentional reading.

Examples:

-   Books
-   Documentation
-   Articles
-   Papers
-   Essays

Reading should have first-class support for:

-   Book
-   Author
-   Current page
-   Total pages
-   Reading sessions
-   Notes
-   Quotes/highlights
-   Progress

## EXPLORE

Curiosity and internet research.

Examples:

-   Browsing
-   Technology research
-   Documentation rabbit holes
-   New concepts
-   Interesting websites
-   Research chains

This category intentionally treats exploration as valuable rather than
automatically labeling web usage as distraction.

A future "Rabbit Hole" feature may represent a chain such as:

``` text
Cloudflare Workers
        ↓
Durable Objects
        ↓
SQLite
        ↓
Distributed systems
        ↓
How Discord handles state
```

## LIFE

Everything outside the other three categories.

Examples:

-   Walking
-   Exercise
-   Cleaning
-   Sleep
-   Errands
-   Social activities
-   Personal tasks
-   Rest

------------------------------------------------------------------------

# Core Data Model

The exact implementation may evolve, but the conceptual model should
remain stable.

## Entry

An Entry represents something the user actually did.

Suggested fields:

``` text
id
category
title
description
date
startedAt
endedAt
duration
quantity
quantityUnit
projectId
bookId
proofItems[]
tags[]
createdAt
updatedAt
```

Possible quantity units:

-   minutes
-   hours
-   pages
-   kilometers
-   sessions
-   items
-   custom

An entry may use duration, quantity, or neither.

Do not force every entry into a duration.

------------------------------------------------------------------------

## Project

Projects represent things the user builds over time.

Example:

``` text
PDS Express
Libreng Sakay
TRACE
Nuxt CLI
```

Suggested fields:

``` text
id
name
description
status
startedAt
endedAt
totalTrackedTime
createdAt
updatedAt
```

A project should aggregate related BUILD entries.

------------------------------------------------------------------------

## Book

Suggested fields:

``` text
id
title
author
cover
currentPage
totalPages
status
startedAt
finishedAt
notes[]
createdAt
updatedAt
```

Statuses:

-   Want to Read
-   Reading
-   Finished
-   Abandoned

------------------------------------------------------------------------

## Note

A Note is lightweight reflection attached to a day, entry, project, or
book.

The default daily reflection is intentionally tiny:

> "One line"

Example:

> Finally figured out the architecture.

Do not turn this into a mandatory journaling workflow.

------------------------------------------------------------------------

## Proof

Proof is optional evidence that an entry happened.

Examples:

-   Git commit
-   Screenshot
-   Note
-   Link
-   Imported activity
-   File reference

The philosophy is:

> "I actually did this."

Proof is not surveillance and should never be required.

------------------------------------------------------------------------

# Primary Screens

## 1. Today

The home screen.

This is the most important screen in the application.

Suggested structure:

``` text
TRACE                         SEP 10

Good evening,
Leigh.

TODAY

02:34   BUILD
        PDS Express

00:32   READ
        The Design of Everyday Things

00:41   EXPLORE
        Cloudflare Durable Objects

00:28   LIFE
        Walk

────────────────────

+ Add entry

PRESENCE                         78%

────────────────────

ONE LINE

Finally figured out the architecture.
```

Rules:

-   Keep the screen visually quiet.
-   Prioritize today's activity.
-   Avoid dashboard clutter.
-   Use whitespace deliberately.
-   Never make the user feel behind.

------------------------------------------------------------------------

## 2. Quick Add

The fastest way to create an entry.

Suggested interaction:

``` text
What did you do?

> coded for 2 hours on PDS Express
```

The application parses the input and presents a confirmation:

``` text
BUILD

PDS Express

2h
```

The user should be able to edit the parsed result before saving.

Provide lightweight suggestions:

-   Coded on a project
-   Read a book
-   Browsed the web
-   Went for a walk
-   Slept
-   Other

Keyboard-first interaction is desirable on supported devices.

------------------------------------------------------------------------

## 3. Timeline

Timeline is the primary history view.

Do not make the calendar grid the default historical interface.

Example:

``` text
SEPTEMBER 2026

10 THU
────────────────────

BUILD
2h 34m
PDS Express

READ
32 pages
The Design of Everyday Things

EXPLORE
41m
Cloudflare Durable Objects

LIFE
28m
Walk


09 WED
────────────────────
...
```

The timeline should make the user's past feel readable and meaningful.

------------------------------------------------------------------------

## 4. Projects

Show active and historical projects.

Example:

``` text
PROJECTS

PDS Express
████████████████░░  78%
47h 31m

Libreng Sakay
████████████░░░░░░  61%
32h 08m

TRACE
████████░░░░░░░░░░  36%
12h 44m
```

Avoid pretending that project percentages are objectively meaningful
unless the user explicitly defines a target.

Prefer tracked time and session history over fake progress percentages.

------------------------------------------------------------------------

## 5. Reading

Reading deserves a dedicated experience.

Example:

``` text
READING

The Design of Everyday Things
Don Norman

██████████████░░░░  58%

214 / 368 pages

Last read
Today · 21:15

Current thought

"Good design makes the relationship
between user and object understandable."

Today
27 pages
```

Reading should feel editorial, not like a task list.

------------------------------------------------------------------------

## 6. Insights

Insights should reveal patterns without becoming a productivity
scoreboard.

Useful metrics:

-   Days present
-   Reading days
-   Building days
-   Exploration days
-   Life activity
-   Total reading pages
-   Books finished
-   Project time
-   Most active projects
-   Most explored topics
-   Time distribution

Example:

``` text
SEPTEMBER

CONSISTENCY

BUILD     ● ● ● ● ● ● ○ ●
READ      ● ● ○ ● ● ○ ● ●
EXPLORE   ● ● ● ● ● ● ● ○
LIFE      ● ○ ● ● ○ ● ● ●

TIME SPENT

78h total

BUILD      32%
READ       21%
EXPLORE    27%
LIFE       20%
```

Do not overload Insights with charts.

------------------------------------------------------------------------

# Daily Reflection

The default reflection mechanism is:

## ONE LINE

The user can write one sentence about the day.

Examples:

-   Finally figured out the architecture.
-   Started a book I've wanted to read for months.
-   Spent too long down a rabbit hole, but learned something useful.
-   Built something small today.

The field should be optional.

------------------------------------------------------------------------

# Navigation

Recommended mobile navigation:

``` text
Today     Timeline     +     Projects     More
```

The center `+` action should be visually prominent but not oversized.

Secondary destinations may include:

-   Reading
-   Insights
-   Settings
-   Data/export
-   About

Do not create a large multi-level navigation system.

------------------------------------------------------------------------

# Visual Design System

TRACE should be:

-   Minimal
-   Editorial
-   Technical
-   Quiet
-   Sophisticated
-   Mostly monochrome
-   Navy-accented
-   Spacious
-   Precise

It should NOT look like:

-   A generic SaaS dashboard
-   A fitness app
-   A children's habit tracker
-   A gamified productivity app
-   An AI-generated template
-   A colorful wellness app

## Color

Light theme:

``` text
Background:       #F8F8F6
Primary text:     #111111
Secondary text:   #6B6B6B
Border:           #E4E4E1
Navy:             #0B1F3A
Navy light:       #E8EDF3
```

Dark theme:

``` text
Background:       #0B0D10
Primary text:     #F5F5F2
Secondary text:   #858991
Border:           #242830
Navy:             #18365A
```

Use navy as an accent.

Do not make the entire interface navy.

Avoid unnecessary gradients.

Avoid arbitrary colors for every category.

Category differentiation should primarily use typography, iconography,
spacing, and subtle navy/gray treatments.

------------------------------------------------------------------------

# Typography

Preferred direction:

-   Inter
-   Geist
-   SF Pro
-   IBM Plex Sans

For technical/time values, a restrained monospace font such as:

-   IBM Plex Mono
-   SF Mono

Use typography to create hierarchy rather than oversized cards.

------------------------------------------------------------------------

# Iconography

Icons should be:

-   Simple
-   Thin or medium weight
-   Geometric
-   Consistent

Suggested conceptual icons:

``` text
BUILD     </>
READ      book
EXPLORE   globe
LIFE      simple life/activity symbol
```

Do not use excessive decorative icons.

------------------------------------------------------------------------

# Motion

Motion should be subtle.

Good:

-   Small fade/slide when an entry appears
-   Smooth timeline transitions
-   Gentle progress animation
-   Button press feedback
-   Small confirmation animation after saving

Avoid:

-   Bouncy cards
-   Excessive spring animations
-   Confetti
-   Constant movement
-   Animated backgrounds

The application should feel fast and calm.

------------------------------------------------------------------------

# UX Principles

## Fast

The user should be able to add a simple entry in under 5 seconds.

## Forgiving

Editing and deleting entries should be easy.

## Private-feeling

The UI should communicate that this is the user's personal record.

## Non-judgmental

Never punish the user for inactivity.

## Readable

Historical information should remain understandable months later.

## Low cognitive load

Every screen should have one obvious purpose.

------------------------------------------------------------------------

# Anti-Patterns

Claude should actively avoid introducing these patterns unless
explicitly requested:

-   Streak obsession
-   Badges
-   Leaderboards
-   Social feeds
-   Public profiles
-   Excessive onboarding
-   Forced journaling
-   Excessive notifications
-   Bright category colors
-   Giant KPI cards
-   Fake productivity scores
-   "AI coach" behavior
-   Motivational quotes
-   Generic gradient SaaS designs
-   Excessive rounded cards
-   Dense dashboards
-   Complex settings
-   Mandatory data entry

If a proposed feature does not clearly improve the user's ability to
record, understand, or remember their life, question whether it belongs.

------------------------------------------------------------------------

# AI Philosophy

AI may be useful, but it should remain invisible and assistive.

Good uses:

-   Parse natural-language entries
-   Detect category
-   Extract duration
-   Extract page numbers
-   Suggest a project
-   Summarize reading notes
-   Find patterns in historical activity
-   Convert messy input into structured data

Bad uses:

-   Constant AI coaching
-   Artificial motivational messages
-   Inventing productivity scores
-   Rewriting the user's personal history without consent
-   Making assumptions about what the user "should" do

AI should reduce friction, not become the product.

------------------------------------------------------------------------

# Privacy

Treat personal activity data as sensitive by design.

Principles:

-   Collect the minimum data required.
-   Prefer local-first behavior where practical.
-   Never require an account merely to use basic tracking.
-   Make export possible.
-   Make deletion possible.
-   Explain synchronization clearly.
-   Do not sell activity data.
-   Do not use personal activity data for social comparison.

If cloud sync is implemented, the UX should make the synchronization
model understandable.

------------------------------------------------------------------------

# Local-First Direction

A strong architectural direction for TRACE is local-first.

The application should remain useful without an internet connection for
core operations:

-   View today's entries
-   Add entries
-   Edit entries
-   View timeline
-   Track reading
-   Track projects

Synchronization can happen in the background when available.

Do not make the entire application dependent on network availability
unless there is a strong technical reason.

------------------------------------------------------------------------

# Recommended Mobile Architecture

Unless the project explicitly chooses another stack, prefer:

-   Flutter
-   Dart
-   Clean feature-oriented architecture
-   Riverpod for state management
-   Local SQLite-based persistence
-   Repository pattern
-   Optional cloud synchronization behind a repository abstraction

Keep domain logic independent from UI widgets.

Suggested structure:

``` text
lib/
  app/
    app.dart
    router.dart
    theme/

  core/
    database/
    storage/
    services/
    utils/

  features/
    today/
    entries/
    timeline/
    projects/
    reading/
    insights/
    settings/

  shared/
    widgets/
    models/
```

Do not over-engineer the application.

Architecture should support growth without creating ceremony for simple
features.

------------------------------------------------------------------------

# Development Rules

## Before implementing a feature

Ask:

1.  Does this support the core TRACE philosophy?
2.  Does it reduce friction or increase understanding?
3.  Does it make the application feel more personal?
4.  Does it introduce unnecessary gamification?
5.  Can the same result be achieved with less UI?

Prefer the simpler implementation.

## UI implementation

Before creating a new component:

-   Check whether an existing component can be reused.
-   Maintain consistent spacing.
-   Maintain typography hierarchy.
-   Avoid introducing a new visual pattern for a one-off use case.

## State

Keep state close to the feature that owns it.

Do not create global state for information that can remain local.

## Data

Do not duplicate derived data unnecessarily.

For example, total project time should normally be derived from entries
rather than manually maintained in multiple places.

## Performance

The app should feel instantaneous for normal personal-scale datasets.

Optimize only when evidence suggests a problem.

------------------------------------------------------------------------

# Example User Flow

### Add a coding session

User taps `+`.

``` text
What did you do?

> coded for 2 hours on TRACE
```

Parser produces:

``` text
BUILD
TRACE
2h
```

User confirms.

Entry appears in Today:

``` text
02:00  BUILD
       TRACE
```

Project total automatically updates.

Timeline automatically includes the entry.

Insights automatically include the activity.

No additional forms should be required.

------------------------------------------------------------------------

# Example Reading Flow

User opens Reading.

``` text
The Design of Everyday Things

214 / 368 pages
58%
```

User taps `Log reading`.

``` text
Pages read
> 27

Current thought
> Good design should communicate itself.
```

Save.

TRACE creates:

``` text
READ
The Design of Everyday Things
27 pages
```

and updates the book progress.

------------------------------------------------------------------------

# Future Features

Potential future features, only if they fit the philosophy:

## Rabbit Holes

Represent chains of exploration.

## Git Integration

Import coding activity from GitHub/Git repositories.

## Browser Integration

Optionally capture intentional research sessions.

## Reading Integrations

Import or synchronize books and reading progress.

## Year in Review

Generate a quiet annual summary.

Example:

``` text
2026

17 books
4,821 pages

241 days present

3 major projects

183 topics explored

"I spent this year
building things."
```

## Personal Search

Search across the user's historical entries.

Example:

> "When did I first start learning about Durable Objects?"

The answer should point to the relevant historical entries.

------------------------------------------------------------------------

# Product Personality

TRACE should feel like:

-   A developer's notebook
-   A personal archive
-   A reading log
-   A project journal
-   A quiet terminal
-   A well-designed paper notebook translated to digital

It should not feel like:

-   A fitness tracker
-   A corporate productivity dashboard
-   A social network
-   A motivational coach
-   A game

------------------------------------------------------------------------

# Design North Star

When making a design decision, ask:

> **Would a person who loves black, white, navy blue, coding, books,
> simple interfaces, and disappearing into internet rabbit holes want to
> use this every day?**

If the answer is no, simplify it.

The goal is not to build the most feature-rich habit tracker.

The goal is to build a personal tool that feels so natural that opening
it becomes part of the user's life.

------------------------------------------------------------------------

# Final Principle

TRACE is not about becoming productive enough.

It is about being able to look back and say:

> **"This is what I did with my time."**

Build. Read. Explore. Live.
