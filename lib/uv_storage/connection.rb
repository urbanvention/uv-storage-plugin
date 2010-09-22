require 'digest/sha1'
require 'digest/md5'
require 'uv_cipher'

module Uv
  module Storage
    
    class NodeConnectionFailed < StandardError; end;
    class MissingSignature < StandardError; end;
    class KeyVerificationFailed < StandardError; end;
    
    #
    # 
    #
    #
    # For each request to the server the following parameters are required in the signed hash.
    # 
    #   :signature => {
    #     :action   => 'update'                                        # => The action you want to perform
    #     :time     => Time.now                                        # => Time when the request was send (signature was generated)
    #     :hash     => Digest::SHA1.hexdigest(access_key + secret_key) # => Hash of access key and secret for verification
    #   }
    #
    # The server always return a signed +JSON String+ (signature) that needs to unencrypted with +Uv::Cipher+.
    # Defaults that will always be returned in this +JSON String+ are:
    #
    #   {
    #     :time     => Timestamp                                       # => Timestamp when the signature was generated
    #     :hash     => Digest::SHA1.hexdigest(access_key + secret_key) # => Hash of access key and secret for verification
    #   }
    #
    # Status Codes from the node:
    # 
    # * 200 OK      - Request was successful
    # * 500 FAILED  - The request was unsuccessful (internal server error)
    #
    class Connection
      
      attr_accessor :config
      attr_accessor :client
      attr_reader   :logger
      attr_reader   :cipher
      
      def initialize(config = nil)
        self.logger     = Logger.new("#{RAILS_ROOT}/log/#{RAILS_ENV}.log")
        self.config     = config.nil? ? Uv::Storage::Config.new : config
        self.cipher     = Uv::Cipher.new(self.config.secret_key, self.config.access_key)
        self.client     = HTTPClient.new
      end
      
      # 
      # Retrieves a file from the node.
      #
      # GET: /get/:signature
      # 
      # Parameters as defined in +Uv::Storage::Connection+ are required. Change the action status. 
      # 
      #   :signature => {
      #     :action   => 'get',
      #     :path     => 'path/to/file.ext'   # => Path to the file
      #   }
      #
      # The server will return the file stream.
      #
      # @param  [String]   node          The node on which the file resides
      # @param  [String]   access_level  See +Uv::Storage::File::ACL_*+ for details
      # @param  [String]   path          The path to the file on the node
      # @return [String]   Returns the file content
      # 
      def get(node, access_level, path)
        begin
          @content ||= self.client.get_content( self.url(node, access_level, path) )
        rescue => e
          logger.fatal "Error while retrieving file in Uv::Storage::Connection#get"
          logger.fatal e
          
          raise NodeConnectionFailed.new
        end
        
        return @content
      end
      
      #
      # Generate the appropiate url for a file, for getting and retrieving a file
      #
      # @param  [String]   node          The node on which the file resides
      # @param  [String]   access_level  See +Uv::Storage::File::ACL_*+ for details
      # @param  [String]   path          The path to the file on the node
      # @return [String]   Returns the url, either with signature or not, depending on the access level
      # 
      def url(node, access_level, path)
        params = {
          'action' => 'get',
          'path' => path
        }
        
        @url ||= self.file_url(node, access_level, path, self.compute_signature(params) )
        
        return @url
      end
      
      # 
      # Create a file and send it to the master, so it gets replicated to all nodes.
      #
      # POST: /create/:signature
      # 
      # Parameters as defined in +Uv::Storage::Connection+ are required. Change the action status. 
      # 
      #   :signature => {
      #     :action       => 'create',
      #     :file         => Multipart-Data,      # => Data of the file in the http header (not cipher'd)
      #     :access_level => 'public'             # => public; protected; private;
      #     :md5_checksum => 'rrewfr45g'          # => checksum of the file for verification
      #   }
      #
      # The server will return the file stream.
      #
      # Returns
      # 
      #   {
      #     :status => 1,                   # The status of the transfer, 1=success; 0=failure; 
      #                                     # 0 means that something (anythig went wrong, could be that one node has 
      #                                     # been written and one failed, status will still be 0)
      #     :errors => ["Error Message"],   # Error messages for the request (only if status == failure)
      #     :path => "id/UniqueIdentifier", # The path of the file
      #     :node_domains => ['a0', 'a1'],  # The domain for accessing the asset. It will be used to compute a domain like:
      #                                     # "http://a0.urbanstorage.com/[FileUID]" 
      #                                     #   -> will be the path to the asset
      #     :access_level => 'public'       # public; access-key; private;  
      #   }
      # 
      def create(file, access_level)
        file.close
        
        params = {
          'action' => 'create',
          'access_level' => access_level,
          'md5_checksum' => Digest::MD5.hexdigest(::File.read(file.path)),
          'original_filename' => file.respond_to?(:original_filename) ? file.original_filename : ::File.basename(file.path)
        }
        
        logger.debug "Trying to send file to master http://#{Uv::Storage.master_domain}/create"
        
        signature = self.compute_signature(params)
        
        ::File.open(file.path) do |file|
          data = { 
            :file => file, 
            :signature => signature
          }
          
          begin
            @result = self.client.post("http://#{Uv::Storage.master_domain}/create", data)
          rescue => e
            logger.fatal "An error occured in Uv::Storage::Connection#create"
            logger.fatal e
            
            raise NodeConnectionFailed.new
          end
        end
        
        begin
          @result = self.cipher.decrypt(@result.content)
          @result = JSON.parse(@result)
        rescue => e
          logger.fatal "An error occured in Uv::Storage::Connection#create"
          logger.fatal e
          
          raise KeyVerificationFailed.new
        end
        
        logger.debug "Got /create result from master: #{@result.inspect}"
        
        return @result
      end
      
      # 
      # Retrieves the current status of the node.
      #
      # GET: /status/:signature
      # 
      # Only the required parameters (see +Uv::Storage::Connection+) are required. Change the action status.
      # 
      #   :signature => {
      #     :action   => 'status'
      #   }
      #
      # Returned from the server:
      #
      #   {
      #     :space_overall      => 20,               # => Space overall on the node in GB
      #     :space_free         => 10,               # => Space free on the node in GB
      #     :load_avg           => 0.01              # => Current load on the node
      #   }
      #
      def status(node)
        params = {
          'action' => 'status'
        }
        
        logger.debug "Trying to retrieve the status from a node"
        
        signature = self.compute_signature(params)
        
        @status ||= self.client.get_content( "#{self.base_url(node)}/status/#{signature}" )
        
        begin
          @status = self.cipher.decrypt(@status.content)
          @status = JSON.parse(@status)
        rescue => e
          logger.fatal "An error occured in Uv::Storage::Connection#status"
          logger.fatal e
          
          raise KeyVerificationFailed.new
        end
        
        return @status
      end
      
      # 
      # Retrieves the meta information of a file on a node.
      #
      # GET: /meta/:signature
      # 
      # Parameters as defined in +Uv::Storage::Connection+ are required. Change the action status.
      # 
      #   :signature => {
      #     :action   => 'meta',
      #     :path     => '2010/09/08/12224345223-0.jpg' # => The complete path of the file on the node
      #   }
      #
      # Returned from the server:
      #
      #   {
      #     :access_level      => 'public',                      # => Access level, see +Uv::Storage::ACL_*+ for available types
      #     :content_type      => 'application/octet-stream',    # => Content type according to RFC1892
      #     :file_size         => 4835385489                     # => File size in bytes
      #   }
      #
      def meta(node, path)
        params = {
          'action' => 'meta'
          'path' => path
        }
        
        logger.debug "Trying to retrieve the meta for file #{path} from a node #{node}"
        
        signature = self.compute_signature(params)
        
        @meta ||= self.client.get_content( "#{self.base_url(node)}/meta/#{signature}" )
        
        begin
          @meta = self.cipher.decrypt(@meta.content)
          @meta = JSON.parse(@meta)
        rescue => e
          logger.fatal "An error occured in Uv::Storage::Connection#meta"
          logger.fatal e
          
          raise KeyVerificationFailed.new
        end
        
        return @meta
      end
      
      # 
      # Updates file settings on the node.
      #
      # POST: /update
      # 
      # Parameters as defined in +Uv::Storage::Connection+ are required. Change the action status.
      # Include the signature as POST parameter.
      # 
      #   :signature => {
      #     :action       => 'update',
      #     :path         => '2010/09/08/12224345223-0.jpg', # => The complete path of the file on the node
      #     :access_level => 'protected',                    # => Change the files access level, see +Uv::Storage::ACL_*+ for available types
      #   }
      #
      # Returned from the server:
      #
      #   {
      #     :path         => '2010/09/08/12224345223-1.jpg'     # => Returns the new path of the file
      #   }
      #
      # @param  [Array]   nodes Nodes where the files are stored
      # @param  [String]  path Path of the file on the nodes
      # @param  [Hash]    update_options Fields to update, currently only +access_level+ is supported
      # @return [String]  Returns the new path of the file
      #
      def update(nodes, path, update_options = {})
        params = {
          'action' => 'update'
          'path' => path
        }
        params.update(update_options)
        
        signature = self.compute_signature(params)
        
        nodes.each do |node|
          begin
            @update = self.client.post("#{self.base_url(node)}/update", { :signature => signature })
          rescue => e
            logger.fatal "An error occured in Uv::Storage::Connection#update"
            logger.fatal e

            raise NodeConnectionFailed.new
          end
        end
        
        # unencrypt data
        begin
          @update = self.cipher.decrypt(@update.content)
          @update = JSON.parse(@update)
        rescue => e
          logger.fatal "An error occured in Uv::Storage::Connection#update"
          logger.fatal e
          
          raise KeyVerificationFailed.new
        end
        
        return @update['path']
      end
      
      # 
      # Deletes a file from the node.
      #
      # POST: /delete
      # 
      # Parameters as defined in +Uv::Storage::Connection+ are required. Change the action status.
      # Include the signature as POST parameter.
      # 
      #   :signature => {
      #     :action       => 'delete',
      #     :path         => '2010/09/08/12224345223-0.jpg'  # => The complete path of the file on the node
      #   }
      #
      # Returns 200 OK if successful.
      #
      def delete(nodes, path)
        params = {
          'action' => 'delete'
          'path' => path
        }
        
        signature = self.compute_signature(params)
        
        nodes.each do |node|
          begin
            self.client.post("#{self.base_url(node)}/update", { :signature => signature })
          rescue => e
            logger.fatal "An error occured in Uv::Storage::Connection#delete"
            logger.fatal e

            raise NodeConnectionFailed.new
          end
        end
        
        return true
      end
      
      # 
      # Generate the complete base domain for a node.
      #
      # Uses the +Uv::Storage.asset_domain+ for computing the url. Also takes the +Uv::Storage.use_ssl+ setting into
      # account and changes the url to http:// and https:// accordingly.
      # 
      # == Example
      #
      #   url = self.base_url('node_name')
      #   puts url # => http[s]://node_name.urbanclouds.com
      # 
      # @param  [String] node The node which you need the url for
      # @return [String] The full url pointing to the node
      #
      def base_url(node)
        "#{Uv::Storage.use_ssl ? 'https://' : 'http://'}#{node.to_s}.#{Uv::Storage.asset_domain}"
      end
      
      #
      # Compute the full url to a file in the cloud, including node and access level.
      #
      # Uses the +base_url+ method to generate the basic url. Depending on the access level (public or protected) either
      # a direct url to node and file is generated or a signed url is generated.
      #
      # == Example
      # 
      #   # access level public
      #   url = file_url('node_name')
      #   puts url # => http[s]://node_name.urbanclouds.com/2010/09/file-name.ext
      # 
      #   # access level protected
      #   url = file_url('node_name')
      #   puts url # => http[s]://node_name.urbanclouds.com/2010/09/file-name.ext/signature
      # 
      # @param  [String]  node The which you need the url for
      # @return [String] The full url to the file
      #
      def file_url(node, access_level, path, signature = "")
        logger.debug "Generating file url."
        logger.debug "Node:         #{node.to_s}"
        logger.debug "Access Level: #{access_level}"
        logger.debug "Path:         #{path}"
        logger.debug "Signature:    #{signature}"
        
        if self.access_level == 'public'
          "http://#{self.base_url(node)}/#{path}"
        elsif self.access_level == 'protected'
          raise MissingSignature.new if signature.blank?
          
          "http://#{self.base_url(node)}/get/#{signature}"
        end
      end
      
      protected
      
        def compute_signature(params)
          return cipher.encrypt(params)
        end
      
    end
    
  end
end