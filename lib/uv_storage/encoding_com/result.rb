module Uv
  module Storage
    module EncodingCom
      
      class Result
        
        attr_accessor :object
        attr_accessor :params
        attr_accessor :connection
        attr_accessor :logger
        
        def initialize(params, object)
          self.params = params
          self.object = object
          self.connection = Uv::Storage::Connection.new
          self.logger = Uv::Storage.logger
          
          self.params.stringify_keys!
          
          process_result!
        end
        
        def succeeded?
          
        end
        
        protected
        
          def process_result!
            signature = params['signature']
            
            @results = self.connection.cipher.decrypt(signature)
            
            logger.debug "#{@results.inspect}"
          end
        
      end
      
    end
  end
end