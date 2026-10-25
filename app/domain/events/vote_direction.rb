module Events
  # Maps vote facts to the active vote direction they carry.
  #
  # Withdrawal facts and non-vote facts return +nil+.
  module VoteDirection
    # call-seq:
    #   VoteDirection.for_fact(Events::EventUpvoted.strict(...)) # => "up"
    #   VoteDirection.for_fact(Events::EventVoteWithdrawn.strict(...)) # => nil
    def self.for_fact(fact)
      case fact.event_type
      when EventUpvoted.name then "up"
      when EventDownvoted.name then "down"
      end
    end
  end
end
