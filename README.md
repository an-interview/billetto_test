# Billetto Events

A small Rails application built for the Billetto Ruby on Rails engineer test. It
ingests public events from the Billetto API, lists them, and lets signed-in users
vote on them, using Rails Event Store for the voting feature and Clerk for
authentication.

## Features

- Fetch and ingest public events from the Billetto API with error handling and validation.
- List events (title, date, image, description, organizer, venue).
- Authenticate users with Clerk (sign-up, sign-in, sign-out).
- Upvote / downvote events, switch the active vote, or withdraw it. Only authenticated users can vote.
- Record votes in Rails Event Store with the voter's user id.
- Show vote totals per event via an asynchronous read model that can be rebuilt from events.

## Requirements

- Ruby 3.4
- PostgreSQL
- Chrome (for the browser tests)
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
bin/rails test:system                                 # browser tests (Chrome required)
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
  domain/                 # bounded contexts
    events.rb             # Events module wiring (load!, subscriptions)
    read_models.rb        # ReadModels module wiring
    events/
      event_imported.rb   # facts
      event_upvoted.rb
      event_downvoted.rb
      event_vote_withdrawn.rb
      import_public_events.rb  # command
      importer.rb              # command handler (Billetto -> Event records)
      cast_vote.rb             # command
      withdraw_vote.rb         # command
      vote_recorder.rb         # command handler (publishes vote facts)
      vote_direction.rb        # maps vote facts to "up" / "down"
    read_models/
      event_vote_counts.rb     # sync projection of vote states and tallies
      current_vote.rb          # queries the current-vote projection
  integrations/billetto.rb # Billetto ACL module + error classes
  integrations/billetto/   # adapter, http client, event mapper, fake adapter
  controllers/            # EventsController, VotesController, SessionsController
lib/                      # command bus + middleware, Fact, ObjectRepository, Handler, subscriptions
```

Commands are dispatched through a middleware chain (`lib/command/bus.rb` +
`lib/command/middleware/`): each command runs in a database transaction, emits
an `ActiveSupport::Notifications` event (`command.executed`), and sets the
correlation / causation ids for the events it publishes. A command dispatched
from within an event handler inherits the handled event's correlation id and
uses the event's id as causation id; a top-level command starts a new
correlation id.

Flow for a vote:

```
POST /events/:event_id/vote
  -> VotesController (thin) -> command_bus.call(Events::CastVote)
  -> Events::VoteRecorder -> publishes Events::EventUpvoted or
     Events::EventDownvoted to stream "Event$<id>" (and links it into the
     "EventVotes" stream)
  -> ReadModels::EventVoteCounts (sync) updates event_vote_states and
     event_vote_counts inside the command transaction
  -> listing shows "N up · N down · N total"

DELETE /events/:event_id/vote
  -> VotesController (thin) -> command_bus.call(Events::WithdrawVote)
  -> Events::VoteRecorder -> publishes Events::EventVoteWithdrawn
  -> ReadModels::EventVoteCounts (sync) removes the state row and adjusts the tally
```

## Design choices and assumptions

- **Database**: PostgreSQL (preferred over MySQL for this exercise).
- **Ingestion**: the Billetto adapter returns raw payloads; `Billetto::EventMapper`
  translates them into `Event` attributes (anti-corruption). It tolerates both the
  documented spelling (`organizer`) and the live API spelling (`organiser`,
  nested `categorization.type`).
- **Idempotent import**: events are upserted by `external_id`. A fact
  (`Events::EventImported`) is published only for new or changed events, so
  re-running the import does not create duplicate events or facts.
- **Strict facts**: `Fact.strict` validates the payload against a `SCHEMA` and
  rejects unknown keys, keeping the event log clean.
- **Event streams**: all facts about an event are published to the `Event$<id>`
  stream, so a single event's history (import, votes) can be read together. Vote
  facts are additionally linked into an `EventVotes` stream so the vote-count
  read model can be rebuilt from one stream.
- **Voting**: each vote is an `EventUpvoted` / `EventDownvoted` fact carrying the
  Clerk `user_id` and the direction it replaced. Votes are immutable facts rather
  than mutable rows. Each user has at most one active vote per event: repeating a
  direction records nothing, switching records a fact whose `previous_direction`
  moves the tally, and withdrawal records an `EventVoteWithdrawn` fact that
  subtracts the removed vote. Concurrent vote and withdrawal commands for the same
  (event, user) are serialized with a transaction advisory lock, so a double-click
  cannot record two votes. The active vote is stored in the
  `event_vote_states` projection with a unique `[event_id, user_id]` index, and the
  listing reads that projection in one query for the signed-in user.
- **Counts**: maintained by the same synchronous projection as the vote state;
  `script/rebuild_event_vote_counts.rb` rebuilds both tables by reading the
  `EventVotes` stream. Applying is idempotent — each fact is claimed in the
  `processed_events` ledger, so retries or replays do not double count — and the
  counter update is a single atomic upsert. State and tally update inside the
  voting command's transaction, so a committed vote is immediately reflected in
  both. Withdrawal facts are linked into the same stream, so rebuilds retain
  withdrawals.
- **Authentication**: Clerk's Rack middleware validates the session and
  `Clerk::Authenticatable` exposes it. We read the user id from the session token
  claims instead of calling the Clerk API on every request. Sign out is a real
  `DELETE /sign-out` form, progressively enhanced by a Stimulus controller that
  revokes the Clerk session when clerk-js is present. Sign-in and sign-up widgets
  are mounted by the `clerk-auth` Stimulus controller, so they render on both
  initial loads and Turbo navigation instead of depending on the window `load`
  event.
- **Command bus**: commands go through a chain of middleware (transaction,
  instrumentation, causation/correlation ids) before reaching their handler, as
  described in the developer guide. Async event handlers restore the causing
  event's correlation / causation context when they run.
- **Testing**: Minitest. The Billetto adapter is stubbed with a fake adapter in
  tests; Clerk is replaced with a test double that fabricates a session from a
  request header (`X-Test-Clerk-User-Id`) for integration tests, or from the
  Rails session for browser tests, so no keys or network are needed.
- **Assumptions / limitations**:
  - A single Billetto organisation's public events. The adapter follows the
    API's `has_more` / `next_url` cursor, so an import fetches every page;
    `limit` is the page size (the API caps it at 100).
  - The vote-state projection assumes fresh data. Existing append-only votes from
    before the one-active-vote change are not backfilled or collapsed.
  - The Clerk sign-up / sign-in / sign-out UI is JavaScript driven. Browser
    tests authenticate through a local fake Clerk component
    (`test/support/fake_clerk.js`) and a test-only endpoint, so the full flow
    (sign-up, sign-in, sign-out, voting and the auth restriction) runs in
    headless Chrome. Collaborating with the real Clerk CDN still needs keys and
    network, so that part is verified manually.

## Testing

```sh
bin/rails test          # models, integration ACL, domain, read models, controllers
bin/rails test:system   # Capybara browser tests (headless Chrome required)
```

Coverage includes: `Event` validations, the Billetto adapter and mapper,
importing (including idempotency and validation), the command bus and handlers,
Clerk auth restriction, voting (facts created, switching, withdrawal, state and
counts projected), current-vote batch lookup, concurrency for vote and
withdrawal, and browser tests for the listing, the voting restriction and the
full authentication flow (`test/system/auth_flow_test.rb`, Selenium + headless
Chrome).
