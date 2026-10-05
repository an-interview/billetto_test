# Anti-corruption layer for the Billetto public events API. Third party errors
# are translated into our own so they never bubble up unhandled.
module Billetto
  Error = Class.new(StandardError)
  ConfigurationError = Class.new(Error)
  RequestError = Class.new(Error)
  ConnectionError = Class.new(Error)
  ResponseError = Class.new(Error)

  def self.adapter
    Rails.configuration.billetto
  end
end
