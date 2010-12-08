module Uv
  module Storage
    module EncodingCom
      
      class EncodingFailed < StandardError; end;
      
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
          
          abort("Object is either not saved or not given.") if self.object.blank? or self.object.new_record?
          abort("Not signature in request found.") if self.params['signature'].blank?
          
          process_result!
        end

        def succeeded?
          self.status == 'success'
        end

        protected
        
          def abort(message = nil)
            self.status = 'failed'
            
            logger.fatal "Encoding Failed for #{self.object.class}##{self.object.id}"
            
            if message
              logger.fatal "Fail message: #{message}"
              raise Uv::Storage::EncodingCom::EncodingFailed.new(message)
            else
              raise Uv::Storage::EncodingCom::EncodingFailed.new
            end
          end

          def process_result!
            signature = params['signature']

            @results = self.connection.cipher.decrypt(signature)
            @results.stringify_keys!
            
            errors = @results['errors'].strip rescue nil
            
            if @results['status'].to_i == 0 and not errors.blank?
              abort("Encoding result came back with error, #{errors}")
            end
            
            @results.delete('hash')
            @results.delete('time')

            # find original
            original_mapping = ::Uv::Storage::FileMapping.find_by_object_name_and_object_identifier(
              self.object.class.to_s.downcase.to_s,
              self.object.id,
              :order => 'id asc'
            )
            
            abort("Could not find original.") if original_mapping.blank?

            @results.each do |format, attrs|
              mapping_string = "#{original_mapping.identifier.gsub(::File.extname(original_mapping.identifier), '')}.#{self.uploader.extension?(format)}"

              mapping                   = Uv::Storage::FileMapping.new
              mapping.nodes             = attrs['node_domains']
              mapping.access_level      = attrs['access_level']
              mapping.file_path         = attrs['path']
              mapping.object_name       = self.object.class.to_s.downcase
              mapping.object_identifier = self.object.id
              mapping.identifier        = [format, mapping_string].compact.join('_')
              
              unless mapping.save
                abort("Failed to save encoding result, here is the mapping: #{mapping}")
              end
            end

            self.status = 'success'
          end

      end

    end
  end
end