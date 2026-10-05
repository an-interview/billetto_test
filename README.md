# Billetto Events

A small Rails application built for the Billetto Ruby on Rails engineer test. It
ingests public events from the Billetto API, lists them, and lets signed-in users
vote on them, using Rails Event Store for the voting feature and Clerk for
authentication.

## Features

- Fetch and ingest public events from the Billetto API with error handling and validation.
- List events (title, date, image, description, organizer, venue).
- Authenticate users with Clerk (sign-up, sign-in, sign-out).
- Upvote / downvote events. Only authenticated users can vote.
- Record votes in Rails Event Store with the voter's user id.
- Show vote totals per event via an asynchronous read model that can be rebuilt from events.

## Requirements

- Ruby 3.4
- PostgreSQL
- A Billetto API key pair — https://api.billetto.com
- A Clerk application (secret + publishable keys) — https://dashboard.clerk.com

## Setup

```sh
bundle install
cp .env.example .env        # then fill in the keys below
bin/rails db:create db:migrate

# Import events from Billetto
bin/rails events:import LIMIT=100

bin/rails server            # http://localhost:3000
```

Add `http://localhost:3000` as an allowed origin / redirect URL in your Clerk
application so the sign-in redirects work.

## Environment variables

Stored in `.env` (git-ignored). See `.env.example`.

| Variable                 | Required | Purpose                                        |
| ------------------------ | -------- | ---------------------------------------------- |
| `BILLETTO_API_KEYPAIR`   | yes      | Billetto `Api-Keypair` header value (`id:secret`) |
| `BILLETTO_API_BASE_URL`  | no       | Overrides the API base (default `https://billetto.dk/api/v3`) |
| `CLERK_SECRET_KEY`       | yes      | Clerk backend key (`sk_...`)                   |
| `CLERK_PUBLISHABLE_KEY`  | yes      | Clerk frontend key (`pk_...`)                  |

## Useful commands

```sh
bin/rails events:import LIMIT=50                      # ingest events
bin/rails runner script/rebuild_event_vote_counts.rb  # rebuild vote counts from events
bin/rails test                                        # unit + integration tests
bin/rails test:system                                 # browser tests (SELENIUM=1 for real Chrome)
bin/ci                                                # full CI: style, security, tests
```

In development, the Rails Event Store browser is mounted at `/res`.

## Architecture

The app follows the conventions in the team's developer guide: thin controllers
that parse params and send commands to a command bus, domain modules, domain
events ("facts"), event handlers / read models, and anti-corruption layers for
third-party APIs.

```
app/
  domain/                 # bounded context: Events
    events.rb             # module wiring (load!, subscriptions)
    events/
      event_imported.rb   # facts
      event_upvoted.rb
      event_downvoted.rb
      import_public_events.rb  # command
      importer.rb              # command handler (Billetto -> Event records)
      cast_vote.rb             # command
      vote_recorder.rb         # command handler (publishes vote facts)
    read_models/
      event_vote_counts.rb     # async read model of vote tallies
  integrations/billetto/  # ACL over the Billetto API (adapter, mapper, fake adapter)
  controllers/            # EventsController, VotesController, SessionsController
lib/                      # command bus, Fact, ObjectRepository, Handler, subscriptions
```

Flow for a vote:

```
POST /events/:event_id/vote
  -> VotesController (thin) -> command_bus.call(Events::CastVote)
  -> Events::VoteRecorder -> publishes Events::EventUpvoted to stream "Event$<id>"
  -> ReadModels::EventVoteCounts (async) updates event_vote_counts
  -> listing shows "N up · N down · N total"
```

## Design choices and assumptions

- **Database**: PostgreSQL (preferred over MySQL for this exercise).
- **Ingestion**: the Billetto adapter returns raw payloads; `Billetto::EventMapper`
  translates them into `Event` attributes (anti-corruption). It tolerates both the
  documented spelling (`organizer`) and the live API spelling (`organiser`, nested
  `categorization.type`, `minimum_price`).
- **Idempotent import**: events are upserted by `external_id`. A fact
  (`Events::EventImported`) is published only for new or changed events, so
  re-running the import does not create duplicate events or facts.
- **Strict facts**: `Fact.strict` validates the payload against a `SCHEMA` and
  rejects unknown keys, keeping the event log clean.
- **Event streams**: all facts about an event are published to the `Event$<id>`
  stream, so a single event's history (import, votes) can be read together and
  read models rebuilt from it.
- **Voting**: each vote is an `EventUpvoted` / `EventDownvoted` fact carrying the
  Clerk `user_id`. Votes are immutable facts rather than mutable rows.
- **Counts**: maintained by an asynchronous read model; `script/rebuild_event_vote_counts.rb`
  rebuilds them from the event store at any time.
- **Authentication**: Clerk's Rack middleware validates the session and
  `Clerk::Authenticatable` exposes it. We read the user id from the session token
  claims instead of calling the Clerk API on every request.
- **Testing**: Minitest. The Billetto adapter is stubbed with a fake adapter in
  tests; Clerk is replaced with a test double that fabricates a session from a
  header (`X-Test-Clerk-User-Id`), so no keys or network are needed.
- **Assumptions / limitations**:
  - A single Billetto organisation's public events; no pagination yet (the API
    caps `limit` at 100).
  - Voting is append-only; there is no "one vote per user" toggle yet. Adding it
    would mean projecting each user's current vote into a read model.
  - The Clerk sign-up / sign-in / sign-out UI is JavaScript driven; automated
    browser tests cover the listing, vote controls, and the auth restriction, while
    the interactive Clerk flow is verified manually.

## Testing

```sh
bin/rails test          # models, integration ACL, domain, read models, controllers
bin/rails test:system   # Capybara (rack_test by default; SELENIUM=1 for headless Chrome)
```

Coverage includes: `Event` validations, the Billetto adapter and mapper,
importing (including idempotency and validation), the command bus and handlers,
Clerk auth restriction, voting (facts created, counts projected), and browser
tests for the listing and the voting restriction.
