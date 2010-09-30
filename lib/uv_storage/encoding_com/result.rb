module Uv
  module Storage
    module EncodingCom
      
      class Result
        
        attr_accessor :object
        attr_accessor :params
        attr_accessor :connection
        attr_accessor :logger
        attr_accessor :status
        
        def initialize(params, object)
          self.params = params
          self.object = object
          self.connection = Uv::Storage::Connection.new
          self.logger = Uv::Storage.logger
          
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
            
            logger.debug "Original mapping: #{original_mapping.inspect}"
            
            @results.each do |format, attrs|
              object_name       = self.object.class.to_s.downcase
              object_identifier = self.object.id
              identifier        = [format, original_mapping.identifier].compact.join('_')
              
              logger.debug "Object name: #{object_name}"
              logger.debug "Object identifier: #{object_identifier}"
              logger.debug "Object Identifier: #{identifier}"
              
              mapping = ::Uv::Storage::FileMapping.find_by_object_name_and_object_identifier_and_identifier(
                object_name, object_identifier, identifier
              )
              
              logger.debug "Found FileMapping: #{mapping.inspect}"
              
              mapping.nodes             = attrs['node_domains']
              mapping.access_level      = attrs['access_level']
              mapping.file_path         = attrs['path']
              
              logger.debug "Updating record"
              
              mapping.save!
            end
            
            self.status = 'success'
          end
        
      end
      
    end
  end
end