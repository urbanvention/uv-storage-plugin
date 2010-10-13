##
# @todo Document
# @author Max Schulze
#
module Uv
  module Storage

    class Pdf

      attr_accessor :object
      attr_accessor :url
      attr_accessor :connection
      attr_accessor :logger
      attr_accessor :options

      def initialize(options = {})
        options.stringify_keys!

        self.url            = options.delete('url')
        self.object         = options.delete('object')
        self.connection     = Uv::Storage::Connection.new
        self.logger         = Uv::Storage.logger
        self.options        = options

        raise ArgumentError.new if self.url.blank? or self.object.blank?
      end

      def process!
        params = {
          :source => 'html',
          :url => self.url
        }
        params.update(self.options)

        @result = self.connection.request('/apis/pdf/create', 'post', params)

        mapping = Uv::Storage::FileMapping.new(
          :nodes => @result['node_domains'],
          :file_path => @result['path'],
          :access_level => @result['access_level'],
          :object_name => self.object.class.to_s.downcase,
          :object_identifier => self.object.id,
          :identifier => self.options['identifier']
        )

        logger.debug "Trying to save mapping in Uv::Storage::File#save"
        logger.debug mapping.inspect

        raise ActiveRecordObjectInvalid.new() unless mapping.valid?
        mapping.save

        file = Uv::Storage::File.new(:object => self.object, :mapping => mapping)

        return file
      end

    end

  end
end