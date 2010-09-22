module Uv
  module Storage
    
    class MissingFileMapping < StandardError; end;
    class FileObjectMissing < StandardError; end; 
    class NodesMissing < StandardError; end;
    class ActiveRecordObjectMissing < StandardError; end;
    class ActiveRecordObjectInvalid < StandardError; end;
    
    class File
      
      # RAW File object for saving
      attr_accessor :raw_file
      
      # Options given when initialized
      attr_accessor :options
      
      # Current config
      attr_accessor :config
      
      # Meta information
      attr_accessor :meta
      
      # HTTPClient instance
      attr_accessor :client
      
      # UV Storage Conncetion instance
      attr_accessor :connection
      
      # Object this file belongs to
      attr_accessor :object
      
      # access level of the current object in the cloud
      attr_accessor :access_level
      
      # rails logger
      attr_reader :logger
      
      # access levels, see +access_level+ for more details
      ACL_PUBLIC    = 'public'
      ACL_PROTECTED = 'protected'
      ACL_PRIVATE   = 'private'
      ACL_EXPIRING  = 'expiring'
      
      # 
      # Initializes a new +Uv::Storage+ object either for retrieving a file or for creating a new file.
      # 
      # == Examples
      #   
      #   # Create a new file by passing in a +File+ Object
      #   Uv::Storage::File.new(File.new("/path/to/file"), :object => Photo.all.first)   
      #   
      #   # Retrieve an existing file
      #   Uv::Storage::File.new(:object => Photo.all.first)
      #
      # The first argument, the +File+ object is optional. You only need to supply a +File+ if you want to store a new
      # file into the cloud. The second argument is a options +Hash+. <b>The +:object+ key is required both for retrieving and
      # storing files, at the moment. It is used to identify the +File+ and map the necessary file id.</b>
      #
      # The +File+ object needs to be either a Ruby +File+ object or a +Tempfile+ object.
      # 
      def initialize(*args)
        self.logger     = Logger.new("#{RAILS_ROOT}/log/#{RAILS_ENV}.log")
        self.options    = {
          :access_level => 'public-read',
          :file_mapping => nil,
          :object => nil
        }
        self.options.update(args.extract_options!)
        self.options.stringify_keys!
        
        self.raw_file   = args.first if args.first.is_a?(File) or args.first.is_a?(Tempfile)
        self.config     = Uv::Storage::Config.new
        self.client     = HTTPClient.new
        self.connection = Uv::Storage::Connection.new(self.config)
        self.object     = self.options['object']
        
        raise ActiveRecordObjectMissing.new if self.object.blank?
        validate_object(self.object)
        
        logger.debug "Initializing new Uv::Storage::File"
        logger.debug "Config loaded:        #{config.inspect}"
        logger.debug "Connection loaded:    #{connection.inspect}"
        logger.debug "Object given:         #{object.inspect}"
        logger.debug "Raw File given:       #{raw_file.inspect}"
        logger.debug "Options given:        #{options.inspect}"
      end
      
      class << self
        
        # 
        # Check wether an object exists in the +Uv::Storage+ cloud or not.
        # 
        # @param  [Integer]            id      Optional: the id of the +Uv::Storage::FileMapping+ to look for.
        # @param  [ActiveRecord::Base] object  Optional: the object the file should be associated to.
        # @return [Boolean]                    true if the file exists, false if it does not.
        # 
        # Either an id or an object has to be given.
        #
        def exists?(*args)
          begin
            if args.first.is_a?(Integer)
              # find the mapping
              mapping = Uv::Storage::FileMapping.find_by_id(args.first)

              raise MissingFileMapping.new unless mapping.present?
            elsif args.first.kind_of?(ActiveRecord::Base)
              mapping = Uv::Storage::FileMapping.find_by_object_name_and_object_identifier(
                args.first.class.to_s.downcase, 
                args.first.id
              )
            end
            
            @file = Uv::Storage::StorageFile.new(:file_mapping => mapping)
            return @file.read.blank? ? true : false
          rescue MissingFileMapping => e
            return false
          end
        end
        
      end
      
      # 
      # Copy a file to a new +ActiveRecord::Base+ object.
      #
      # @param  [ActiveRecord::Base]   object  the object to copy the file to
      # @return [Boolean]
      #
      def copy(to_object)
        validate_object(to_object)
        
        begin
          logger.debug "Initialized Uv::Storage::File#copy"
          logger.debug "Trying to download the file, and write it to a tempfile"
          
          tmp_file_name   = ::File.join(RAILS_ROOT, 'tmp', self.filename)
          tmp_file        = ::File.new(tmp_file_name, 'w') 
          tmp_file.write(self.read)
          
          logger.debug "Tempfile written to: #{tmp_file_name}"         
          logger.debug "Creating a new file to copy to."

          new_file = Uv::Storage::File.new(tmp_file, :object => to_object)
          new_file.save

          return true
        rescue => e
          logger.fatal "An error occured in Uv::Storage::File#copy"
          logger.fatal "Error was: #{e}"
          
          return false
        end
      end
      
      # 
      # Returns the access level of the given file object in the cloud. This can be one of the following (String):
      # 
      # * Uv::Storage::File::ACL_PUBLIC    - <b>default</b> File is publicly readable without any verification or 
      #   authentication (fastest in read perfomance)
      # * Uv::Storage::File::ACL_PROTECTED - Only allow to read the file with an signature, which expires every 5 minutes
      # * Uv::Storage::File::ACL_PRIVATE   - Do not make the file publicly available, can only be accessed by the server it self
      # * Uv::Storage::File::ACL_EXPIRING  - Special file that expires after a certain time (then turns private)
      # 
      # Use the constants if you want check a certain access level of a file.
      #
      # The access_level of the file is kept locally in the database. If this value does not exist or +force+ is given,
      # the access_level will be pulled remotely from the storage node. 
      # 
      # == Example
      # 
      #   uv_file = Uv::Storage::File.new(:object => Photo.all.first)
      #
      #   if uv_file.access_level == Uv::Storage::File::ACL_PUBLIC
      #     # file is public
      #   end
      #   
      # @param [Boolean] force Force an update from the server
      # @return [String] the access level of the file or false if non exists
      # 
      def access_level(force = false)
        if not force and self.mapping.present? and self.mapping.access_level.present?
          return self.mapping.access_level
        else
          retrieve_meta!
          
          return self.meta.nil? ? false : self.meta['access_level'].to_s
        end
      end
      
      # 
      # Updates the access_level of a file.
      # 
      # If the file has already been saved to +Uv::Storage+ a server update command will be send and the exisiting
      # +Uv::Storage::FileMapping+ will be updated. In any case (even if the file is not yet saved), the options will
      # be updated, so that upon saving the file the access_level will be set correctly. 
      # 
      # Use one of the +Uv::Storage::ACL_*+ constants for setting the access level.
      # 
      # == Example
      # 
      #   # Setting the access level of a new file
      #   file              = Uv::Storage::File.new(File.new("path/to/file"), :object => Photo.all.first)
      #   file.access_level = Uv::Storage::ACL_PUBLIC
      #   file.save
      #   
      #   # Setting the access level of an existing file
      #   file              = Uv::Storage::File.new(:object => Photo.all.first)
      #   
      #   if file.access_level == Uv::Storage::ACL_PUBLIC
      #     # if the file is public, set it to protected
      #     file.access_level = Uv::Storage::ACL_PROTECTED
      #   end
      # 
      # @param  [String]  access_level The new +access_level+ of the file, should be one of the +Uv::Storage::ACL_*+ constants.
      #                                If the +access_level+ is invalid, +Uv::Storage::ACL_PUBLIC+ is used.
      # @return [Boolean] Returns true or false wether the operation succeeded or failed.
      # 
      def access_level=(lvl)
        @access_level = lvl
        lvl = uv_access_level
        
        logger.debug "Setting new access_level in Uv::Storage::File#access_level="
        logger.debug "New access_level is '#{lvl}'"
        
        begin
          if self.mapping.present?
            logger.debug "File already exists on Uv::Storage, trying to update the record"
            
            self.connection.update(mapping, { :access_level => lvl } )        
            self.mapping.access_level = lvl 
            self.mapping.save
          end
        rescue => e
          logger.fatal "Failed to update remote file and save mapping."
          logger.fatal "Error was: #{e}"
          
          return false
        end
        
        # update the options (if the file will be saved afterwards)
        self.options['access_level'] = lvl
        
        return true
      end
      
      # 
      # Retrieve the cloud filename, which will return something like 1223434342.jpg
      # 
      # == Example
      # 
      #   file = Uv::Storage::File.new(:object => Photo.all.first)
      #   file.filename # => returns the file name if a object exists, raises exception if an error occurs
      # 
      # @return [String]  Returns the filename of the cloud file
      # 
      def filename
        raise MissingFileMapping.new if mapping.blank?
        
        return mapping.path.present? ? File.basename(File.join("/", mapping.path)) : false
      end
      
      # 
      # Retrieve the url for the file in the +Uv::Storage+ cloud.
      # 
      # TODO: Implement expires logic
      # This will return an url to a storage node with the file on it. Depending on the access level either a
      # public url will be generated or a signed url is going to be created.
      # 
      # If you pass in a expires time in seconds, you will get an expiring url. This url will invalidate after the 
      # time you provided.
      #
      # == Example
      # 
      #   file = Uv::Storage::File.new(:object => Photo.all.first)
      #   file.url # => Returns a string with the url
      #
      # @param  [Integer]   expires Time in seconds when the url should expire
      # @return [String]    Returns a url string, or raises an exception if something is missing
      # 
      def url(expires = nil)
        raise MissingFileMapping.new if mapping.blank?
        raise NodesMissing.new if mapping.nodes.blank?
        
        logger.debug "URLs are beeing generated."
        
        @urls = []
        self.nodes.each do |node|
          @urls << file_url(node)
        end
        
        @urls.shuffle!
        @url = @urls.first
        
        return @url
      end
      
      # 
      # Delete a file from the +Uv::Storage+ cloud.
      #
      # This will delete a file from the cloud and raise if an exception if something is wrong.
      # 
      # == Example
      # 
      #   file = Uv::Storage::File.new(:object => Photo.all.first)
      #   file.destroy => true on success or false if failed
      # 
      def destroy
        raise MissingFileMapping.new if mapping.blank?
        raise NodesMissing.new if mapping.nodes.blank?
        
        begin
          self.connection.delete(mapping)

          return true
        rescue => e
          logger.fatal "There was an error deleting the file."
          logger.fatal "#{e}"
          
          return false
        end
      end
      
      # 
      # Return the +content_type+ of the file.
      # 
      # This will call the server, retrieve the necessary meta information and will return you the correct 
      # content_type for the file. This method calls the server, so the content_type should be cached.
      # 
      # == Example
      # 
      #   file = Uv::Storage::File.new(:object => Photo.all.first)
      #   file.content_type
      # 
      # @return [String]    String with the content_type e.g. application/octet-stream, false or exception if someting
      # goes wrong
      # 
      def content_type
        raise MissingFileMapping.new if mapping.blank?
        raise NodesMissing.new if mapping.nodes.blank?
        
        retrieve_meta!
        
        return self.meta['content_type'].to_s
      end
      
      # 
      # Return the +size+ of the file.
      # 
      # This will call the server, retrieve the necessary meta information and will return you the correct 
      # size in bytes for the file. This method calls the server, so the size should be cached.
      # 
      # == Example
      # 
      #   file = Uv::Storage::File.new(:object => Photo.all.first)
      #   file.size # => Returns the size in bytes
      # 
      # @return [Integer]    Returns the size in bytes, raises exception or returns false if something goes wrong
      #
      def size
        raise MissingFileMapping.new if mapping.blank?
        raise NodesMissing.new if mapping.nodes.blank?
        
        retrieve_meta!
        
        return self.meta['size'].to_s
      end
      
      # 
      # Read the contents of the file and return the raw data.
      # 
      # This will call the server with the +url+ method and read the contents of the file. This emulates the ruby
      # +File#read+ method. This method calls the server so the result should be cached.
      # 
      # == Example
      # 
      #   file = Uv::Storage::File.new(:object => Photo.all.first)
      #   open("new/file/path", 'w') do |f| 
      #     f.write file.read # => Will read the file and write it to a local one
      #     f.close
      #   end
      #
      # @return [String]    Returns the raw data as a +String+
      #
      def read
        raise MissingFileMapping.new if mapping.blank?
        raise NodesMissing.new if mapping.nodes.blank?
        
        @content ||= self.connection.get_file_content(self.mapping)
        
        return @content
      end
            
      # 
      # Close is an alias for +save+.
      # 
      def close
        save
      end
      
      # 
      # Saves the current file in the cloud by sending it to the +Uv::Storage+ master.
      #
      # After the file has been created in the +Uv::Storage+ cloud, the resulting information will be saved in 
      # the +Uv::Storage::FileMapping+ table, together with the associated object.
      # 
      # == Example
      # 
      #   file = Uv::Storage::File.new(File.new('path/to/file), :object => Photo.all.first)
      #   file.save # => saves the file to the cloud
      # 
      # @return [Boolean]   True if succeeded or false if the request failed.
      # 
      def save
        return if self.mapping.present? # already saved that file
        validate_object(self.object)
        
        logger.debug "Sending file to master in Uv::Storage::File#save"
        
        @result = send_file_to_master!
                  
        self.mapping = Uv::Storage::FileMapping.new( 
          :nodes => @result['node_domains'], 
          :file_path => @result['path'], 
          :access_level => @result['access_level'],
          :object_name => self.object.class.to_s.downcase,
          :object_identifier => self.object.id
        )
          
        logger.debug "Trying to save mapping in Uv::Storage::File#save"
        logger.debug self.mapping.inspect
        
        raise ActiveRecordObjectInvalid.new() unless self.mapping.valid?
        
        return self.mapping.save
      end
      
      #
      # Returns the nodes where this file resides.
      #
      # Each file will be stored on at least one node, the replication level of each file (the number of nodes to which,
      # will be replicated to) can be set on the master-server by an administrator. If a node goes down, it will be 
      # removed from the database, so this value may change.
      # 
      # Reads the nodes array from the +FileMapping+ table. The array contains string with subdomains, those can be 
      # computed to a full url with Uv::Storage.asset_domain. This method should only be used internaly.
      #
      # == Example
      # 
      #   file = Uv::Storage::File.new(:object => Photo.all.first)
      #   nodes = file.nodes
      #
      #   # compute url
      #   url = "http://#{nodes.first.to_s}.#{Uv::Storage.asset_domain}/"
      #
      # @return [Array]     Array of nodes. Contains strings with node subdomains
      #
      def nodes
        raise MissingFileMapping.new if mapping.blank?
        
        return mapping.nodes
      end
      
      # 
      # Returns the path of the file on the nodes.
      # 
      # Each file will be stored on multiple nodes, but they will always have the same path on all nodes. This path
      # to the file will be saved in the +Uv::Storage::FileMapping+ so there is no need for an extra request to retrieve
      # the url.
      # 
      # This should only be used internaly, because it ignores the access level of the file.
      #
      # == Example
      # 
      #   file  = Uv::Storage::File.new(:object => Photo.all.first)
      #   nodes = file.nodes
      #   path  = file.path
      #
      #   # compute url
      #   url = "http://#{nodes.first.to_s}.#{Uv::Storage.asset_domain}/#{path}"
      # 
      # @return [String]    The global path to the file on all nodes where it is stored.
      # 
      def path
        raise MissingFileMapping.new if mapping.blank?
        
        return mapping.file_path.to_s
      end
      
      protected
        
        #
        # Validates the ActiveRecord::Base object for building the +FileMapping+ association.
        # 
        # Checks the model if it is present, valid and saved. Raises an +ActiveRecordObjectInvalid+ Exception if something
        # about the object is invalid.
        # 
        # @param [ActiveRecord::Base] object The ActiveRecord object to validate
        # 
        def validate_object(object)
          raise ActiveRecordObjectInvalid.new("The object is nil") if object.nil?
          raise ActiveRecordObjectInvalid.new("The object is not valid") unless object.valid?
          raise ActiveRecordObjectInvalid.new("The object needs to be saved first") if object.new_record?
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
        def file_url(node)
          logger.debug "Generating file url."
          logger.debug "Node:         #{node.to_s}"
          logger.debug "Access Level: #{self.access_level}"
          logger.debug "Path:         #{self.path}"
          
          if self.access_level == 'public'
            "http://#{self.base_url(node)}/#{self.path}"
          elsif self.access_level == 'protected'
            "http://#{self.base_url(node)}/get/#{self.path}/#{self.connection.signature}"
          end
        end
        
        #
        # 
        #
        def send_file_to_master!
          puts "Trying to send file to master http://#{Uv::Storage.master_domain}/create"
          
          self.raw_file.close
          File.open(self.raw_file.path) do |file|
            data = { 
              :file => file, 
              :signature => self.connection.signature, 
              :access_key => self.config.access_key,
              :access_level => uv_access_level || 'public',
              :original_filename => self.raw_file.respond_to?(:original_filename) ? self.raw_file.original_filename : File.basename(self.raw_file.path)
            }
            
            @result = self.client.post("http://#{Uv::Storage.master_domain}/create", data)
          end
          
          @result = JSON.parse(@result.content)
          
          puts "Send file to master: #{@result.inspect}"
          
          return @result
        end
        
        # 
        # Convert amazon style access level to internal one
        # 
        def uv_access_level
          case self.access_level.to_s
          when 'public-read', 'public'
            'public'
          when 'authenticated-read', 'protected'
            'protected'
          when 'private'
            'private'
          else
            'public'
          end
        end
        
        def mapping
          self.options['file_mapping']
        end
        
        def mapping=(map)
          self.options['file_mapping'] = map
        end
      
        def retrieve_meta!
          begin
            if self.meta.blank?
              content = self.client.get_content("http://#{self.nodes.first}.#{Uv::Storage.asset_domain}/meta/#{self.path}/#{self.connection.signature}")
              self.meta = JSON.parse(content)
            end
          rescue
            self.meta = nil
          end
          
          return self.meta
        end
      
    end
    
  end
end