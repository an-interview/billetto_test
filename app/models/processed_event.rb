# Ledger of domain events already applied by a read model handler.
#
# A read model is applied at-least-once (background job retries, replays), so
# each handler records the events it has processed here and skips duplicates.
class ProcessedEvent < ApplicationRecord
end
