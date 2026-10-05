# Registers the application's domain objects with ObjectRepository.
#
# Referencing each class makes Zeitwerk load it, which runs `has_typeid` and
# registers the type id. New domain objects must be added here.
Rails.configuration.to_prepare do
  Event
end
