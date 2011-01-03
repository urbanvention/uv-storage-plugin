require 'yaml'

module Uv
  module Storage

    class Config

      # Current path to the config
      attr_accessor :config_path

      # Currently loaded configuration
      attr_accessor :config
      attr_reader :logger
      #
      # Initialize the configuration object
      # Loads the configuration from RAILS_ROOT/config/uv_storage.yml if +config_path+ is omitted.
      #
      # == Examples:
      #
      #   @config = Uv::Storage::Config.new(path_to_config_file)
      #   @config.access_key    # You can access the config file values directly as a object method
      #   @config.config        # Access the loaded config directly
      #   @config.config_path   # Get the path of the current config file
      #
      def initialize(config_path = nil)
        @logger = Uv::Storage.logger

        self.config_path = config_path.nil? ? "#{RAILS_ROOT}/config/uv_storage.yml" : config_path
        self.config = YAML.load_file(self.config_path)
        self.config.stringify_keys!

        self.config = if RAILS_ENV.present?
          self.config[RAILS_ENV]
        elsif Rails.env.present?
          self.config[Rails.env]
        end
      end

      #
      # If a method is missing, it will try to access the +self.config+ hash to load the value for the
      # called method. If no value or key is present it will raise +MethodNotFound+
      #
      def method_missing(method_name, *args)
        if self.config.has_key?(method_name.to_s)
          return self.config[method_name.to_s]
        else
          super
        end
      end

    end

  end
end