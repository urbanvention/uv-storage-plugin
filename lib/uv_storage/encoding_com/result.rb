module Uv
  module Storage
    module EncodingCom

      class Result

        attr_accessor :object
        attr_accessor :params
        attr_accessor :connection
        attr_accessor :logger
        attr_accessor :status
        attr_accessor :uploader

        def initialize(params, object, uploader = nil)
          self.params = params
          self.object = object
          self.connection = Uv::Storage::Connection.new
          self.logger = Uv::Storage.logger
          self.uploader = uploader

          self.params.stringify_keys!

          process_result!
        end

        def succeeded?
          self.status == 'success'
        end

        protected

          def process_result!
            signature = params['signature']

            @results = self.connection.cipher.decrypt(signature)
            @results.stringify_keys!

            @results.delete('hash')
            @results.delete('time')

            # find original
            original_mapping = ::Uv::Storage::FileMapping.find_by_object_name_and_object_identifier(
              self.object.class.to_s.downcase.to_s,
              self.object.id,
              :order => 'id asc'
            )

            @results.each do |format, attrs|
              mapping = "#{original_mapping.identifier.gsub(::File.extname(original_mapping.identifier), '')}.#{self.uploader.extension?(format)}"

              mapping                   = Uv::Storage::FileMapping.new
              mapping.nodes             = attrs['node_domains']
              mapping.access_level      = attrs['access_level']
              mapping.file_path         = attrs['path']
              mapping.object_name       = self.object.class.to_s.downcase
              mapping.object_identifier = self.object.id
              mapping.identifier        = [format, mapping].compact.join('_')
              mapping.save
            end

            self.status = 'success'

            # logger.debug "#{@results.inspect}"
          end

      end

    end
  end
end