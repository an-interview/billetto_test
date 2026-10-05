module Command
  module Middleware
    # Runs the command in a database transaction, so the command's writes and
    # the domain events it publishes commit or roll back together.
    class Transaction
      def call(_command, next_step)
        ApplicationRecord.transaction { next_step.call }
      end
    end
  end
end
