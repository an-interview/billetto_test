namespace :events do
  desc "Import public events from the Billetto API (LIMIT=50)"
  task import: :environment do
    command = Events::ImportPublicEvents.new(limit: ENV.fetch("LIMIT", 50).to_i)
    result = Rails.configuration.command_bus.call(command)

    puts "Imported #{result.imported}, skipped #{result.skipped}"
  end
end
