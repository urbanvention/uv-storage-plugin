module Uv
  module Storage
    
    class File
      
      # RAW File object for saving
      attr_accessor :raw_file
      
      # Options given when initialized
      attr_accessor :options
      
      # Current config
      attr_accessor :config
      
      # Meta information
      attr_accessor :meta
      
      # UV Storage Conncetion instance
      attr_accessor :connection
      
      # Object this file belongs to
      attr_accessor :object
      
      # access level of the current object in the cloud
      attr_accessor :access_level
      
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
        @logger     = Uv::Storage.logger
        
        @options    = {
          :access_level => 'public-read',
          :file_mapping => nil,
          :object => nil
        }
        @options.update(args.extract_options!)
        @options.stringify_keys!
        
        @raw_file   = args.first
        @config     = Uv::Storage::Config.new
        @connection = Uv::Storage::Connection.new(self.config)
        @object     = @options['object']
        
        logger.debug "Initializing new Uv::Storage::File"
        logger.debug "Args First is a:      #{args.first.class.to_s}"
        logger.debug "Config loaded:        #{config.present?}"
        logger.debug "Connection loaded:    #{connection.present?}"
        logger.debug "Object given:         #{object.present?}"
        logger.debug "Raw File given:       #{@raw_file.present?}"
        logger.debug "Options given:        #{options.present?}"
        logger.debug "Identifier given:     #{options['identifier'].present?}"
        
        validate_object(@object) if @object.present?
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
          options = args.extract_options!
          
          begin
            if args.first.is_a?(Integer)
              # find the mapping
              mapping = Uv::Storage::FileMapping.find_by_id(args.first)

              raise MissingFileMapping.new unless mapping.present?
            elsif args.first.kind_of?(ActiveRecord::Base)
              if options['identifier'].present?
                mapping = Uv::Storage::FileMapping.find_by_object_name_and_object_identifier_and_identifier(
                  args.first.class.to_s.downcase, 
                  args.first.id,
                  options['identifier']
                )
              else
                mapping = Uv::Storage::FileMapping.find_by_object_name_and_object_identifier(
                  args.first.class.to_s.downcase, 
                  args.first.id
                )
              end
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

          new_file        = Uv::Storage::File.new(tmp_file, :object => to_object)
          new_file.save

          return true
        rescue => e
          logger.fatal "An error occured in Uv::Storage::File#copy"
          logger.fatal "Error was: #{e}"
          
          raise e
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
        logger.debug "Setting new access_level in Uv::Storage::File#access_level=#{lvl}"
        
        #@access_level = lvl
        lvl = uv_access_level(lvl)
        
        logger.debug "New access_level is '#{lvl}'"
        
        begin
          if self.mapping.present?
            logger.debug "File already exists on Uv::Storage, trying to update the record"
            
            self.mapping.file_path = self.connection.update(mapping.nodes, mapping.file_path, { 'access_level' => lvl } )
            self.mapping.access_level = lvl 
            self.mapping.save
          else
            raise MissingFileMapping.new
          end
        rescue => e
          logger.fatal "Failed to update remote file and save mapping."
          logger.fatal "Error was: #{e}"
          
          raise e
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
        
        return mapping.file_path.present? ? ::File.basename(::File.join("/", mapping.file_path)) : false
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
        raise MissingFileMapping.new("Identifier: #{options['identifier']}") if mapping.blank?
        raise NodesMissing.new if mapping.nodes.blank?
        
        logger.debug "URLs are beeing generated."
        
        @urls = []
        self.nodes.each do |node|
          @urls << self.connection.url(node, self.access_level, self.path)
        end
        
          logger.debug "URLS: #{@urls.inspect}"
          
        return @urls.shuffle.first        # randomize url for load-balancing
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
          self.connection.delete(mapping.nodes, mapping.file_path)
          self.mapping.delete

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
        
        raise MetaInformationMissing.new if self.meta.blank?
        
        return self.meta['file_size'].to_i
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
        
        @content ||= self.connection.get(self.nodes.first, self.access_level, self.path)
        
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
        
        raise FileObjectMissing.new if self.raw_file.blank?
        
        @result = self.connection.create(self.raw_file, uv_access_level(self.options['access_level']))
        
        self.mapping = Uv::Storage::FileMapping.new( 
          :nodes => @result['node_domains'], 
          :file_path => @result['path'], 
          :access_level => uv_access_level(@result['access_level']),
          :object_name => self.object.class.to_s.downcase,
          :object_identifier => self.object.id,
          :identifier => self.options['identifier']
        )
          
        logger.debug "Trying to save mapping in Uv::Storage::File#save"
        logger.debug self.mapping
        
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
      
      def identifier
        raise MissingFileMapping.new if mapping.blank?
        
        return mapping.identifier.to_s
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
          #raise ActiveRecordObjectInvalid.new("The object is not valid") unless object.valid?
          raise ActiveRecordObjectInvalid.new("The object needs to be saved first") if object.new_record?
        end
        
        # 
        # Convert amazon style access level to internal one
        # 
        def uv_access_level(access_level = nil)
          access_level = self.access_level if access_level.blank?
          
          case access_level.to_s
          when 'public-read', 'public'
            Uv::Storage::File::ACL_PUBLIC
          when 'authenticated-read', 'protected'
            Uv::Storage::File::ACL_PROTECTED
          when 'private'
            Uv::Storage::File::ACL_PRIVATE
          else
            Uv::Storage::File::ACL_PUBLIC
          end
        end
        
        def mapping
          if self.options['file_mapping'].blank? and self.object.present?
            if self.options['identifier'].present?
              self.options['file_mapping'] = Uv::Storage::FileMapping.find_by_object_name_and_object_identifier_and_identifier(
                self.object.class.to_s.downcase.to_s, 
                self.object.id,
                self.options['identifier']
              )
            else
              self.options['file_mapping'] = Uv::Storage::FileMapping.find_by_object_name_and_object_identifier(
                self.object.class.to_s.downcase.to_s, 
                self.object.id
              )
            end
          end
          
          return self.options['file_mapping']
        end
        
        def mapping=(map)
          logger.debug "Setting new mapping"
          
          self.options['file_mapping'] = map
        end
      
        def retrieve_meta!
          logger.debug "Trying to retrieve meta information for file #{self.path}"
          
          begin
            if self.meta.blank?
              self.meta = self.connection.meta(self.nodes.first, self.path)
            end
          rescue => e
            logger.fatal "Error getting meta data"
            logger.fatal e
            
            self.meta = nil
          end
          
          return self.meta
        end
      
    end
    
  end
end