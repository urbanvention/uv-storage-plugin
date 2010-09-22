require 'digest/sha1'

module Uv
  module Storage
    
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
      
      def initialize(config = nil)
        self.config     = config.nil? ? Uv::Storage::Config.new : config
        self.client     = HTTPClient.new
      end
      
      def signature
        Digest::SHA1.hexdigest(self.config.access_key + self.config.secret_key)
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
      def get
        # TODO: Implement
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
      #     :path         => 'path/to/file.ext'   # => Path to the file
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
      def create
        # TODO: Implement
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
      def status
        # TODO: Implement
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
      def meta
        # TODO: Implement
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
      def update(mapping, update_data = {}, options = {})
        # TODO: Implement, be aware that you to delete the file on ALL nodes.
        # TODO: Sign the url and params with cipher
        self.client.post(
          "http://#{self.base_url(mapping.nodes.first)}/update/#{mapping.path}/#{self.signature}", 
          update_data
        )
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
      def delete
        # TODO: Implement, be aware that you to delete the file on ALL nodes.
      end
      
      def base_url(node)
        "http://#{node.to_s}.#{Uv::Storage.asset_domain}"
      end
      
    end
    
  end
end