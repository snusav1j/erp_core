require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ErpCore
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0
    config.i18n.available_locales = [:ru, :en]
    config.i18n.default_locale = :ru
    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])
    config.generators do |g|
      g.template_engine :haml
    end
    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.time_zone = "Europe/Moscow"
    config.active_record.default_timezone = :local
    config.active_record.yaml_column_permitted_classes = [
      Symbol,
      Time,
      Date,
      ActiveSupport::TimeWithZone,
      ActiveSupport::TimeZone
    ]
  end
end
