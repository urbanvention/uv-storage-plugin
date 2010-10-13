# encoding: utf-8
module CarrierWave
  module Storage
    ##
    # Uploads things to urbanvention storage.
    # You'll need to specify in the configuration file of urbanvention storage. See Uv::Storage for reference.
    #
    # You can set the access policy for the uploaded files:
    #
    #     CarrierWave.configure do |config|
    #       config.s3_access_policy = 'public-read'
    #     end
    #
    # The default is 'public-read'. For more options see:
    #
    # For backwards compatability with amazon s3:
    #
    # [:private]              No one else has any access rights.
    # [:public_read]          The anonymous principal is granted READ access.
    #                         If this policy is used on an object, it can be read from a
    #                         browser with no authentication.
    # [:authenticated_read]   Any principal authenticated as a registered Amazon S3 user
    #                         is granted READ access.
    #
    # The resulting url will be
    #
    #     http://node_name.urbanstorage.com/path/signature
    #
    class Uv < CarrierWave::Storage::Abstract

      class File

        attr_accessor :object
        attr_accessor :uv_file
        attr_reader :logger
        attr_accessor :store

        def initialize(uploader, base, path)
          @logger     = Logger.new("#{RAILS_ROOT}/log/uv_storage.log")

          logger.debug 'Initalizing new Carrierwave Uv::File instance'

          @uploader = uploader
          @path = path
          @base = base
          @object = @uploader.model

          @store = true
          if uploader.respond_to?(:uv_store_versions?) and uploader.version_name.present? and not uploader.uv_store_versions?
            @store = false
          end

          logger.debug "Uploader Versions Options: #{@store}"

          # try to find an existing file
          # @object.save_without_validation if @object.new_record?

          if @object.present?
            mapping = ::Uv::Storage::FileMapping.find_by_object_name_and_object_identifier(@object.class.to_s.downcase.to_s, @object.id, :order => 'id asc')
            logger.debug "Found mapping: #{mapping.present?}"
            logger.debug "Version name: #{uploader.version_name.present?}"

            return unless mapping.present?

            # if it is a thumbnail
            if uploader.version_name.present?
              logger.debug "Running initialize #{uploader.version_name}"

              ident = [uploader.version_name, mapping.identifier].compact.join('_')
              @uv_file = ::Uv::Storage::File.new(:object => @object, :identifier => ident)
            else
              logger.debug "Trying to find parent: #{@object.present?} / #{mapping.present?}"
              @uv_file = ::Uv::Storage::File.new(:object => @object, :file_mapping => mapping)
              logger.debug 'Finding parent finished.'
            end
          else
            logger.debug 'New Record created, there was no object given.'
          end

          logger.debug 'Initalizing finished.'
        end

        ##
        # Returns the current path of the file on Uv::Storage
        #
        # === Returns
        #
        # [String] A path
        #
        def path
          @uv_file.path if @uv_file.present?
        end

        def identifier
          @uv_file.filename if @uv_file.present?
        end

        def original_filename
          @uv_file.identifier if @uv_file.present?
        end

        ##
        # Reads the contents of the file from Uv::Storage
        #
        # === Returns
        #
        # [String] contents of the file
        #
        def read
          @uv_file.read if @uv_file.present?
        end

        ##
        # Remove the file from Uv::Storage
        #
        def delete
          @uv_file.destroy if @uv_file.present?
        end

        ##
        # Returns the url on Uv::Storage service
        #
        # === Returns
        #
        # [String] file's url
        #
        def url(expires = nil)
          @uv_file.url(expires) if @uv_file.present?
        end

        def store(file)
          return unless @store

          logger.debug "Storing File in Object: #{file.class}"
          logger.debug "Sanitized file #{file.original_filename} / #{file.file.class}"

          f = ::File.open("#{RAILS_ROOT}/tmp/#{file.original_filename}", "w+")
          f.write file.read
          file.close rescue nil
          ::File.unlink(file.path) rescue nil # remove tmp file

          logger.debug "Saved File #{f.class} / #{::File.basename(f.path)}"

          @uv_file = ::Uv::Storage::File.new(f, :object => @object, :identifier => file.original_filename)

          begin
            @uv_file.save
          rescue Exception => e
            logger.fatal "Error saving file"
            logger.fatal e
          end

          ::File.unlink(f.path) rescue nil
        end

        def access_level=(acl)
          @uv_file.access_level = acl if @uv_file.present?
        end

        # The Amazon S3 Access policy ready to send in storage request headers.
        def method_missing(method_name, *args)
          if @uv_file.present? and @uv_file.respond_to?(method_name.to_sym)# and not method_name.to_s == 'filename'
            @uv_file.send(method_name.to_sym)
          else
            super
          end
        end

        def copy(to_object)
          @uv_file.copy(to_object, @uv_file.identifier)
        end

        def content_type=(type)
          #
        end

        # Headers returned from file retrieval
        def headers
          #
        end

        def setup!
          return
        end
      end


      def setup!
        return
      end
      ##
      # Store the file on Uv::Storage
      #
      # === Parameters
      #
      # [file (CarrierWave::SanitizedFile)] the file to store
      #
      # === Returns
      #
      # [Uv::Storage::File] the stored file
      #
      def store!(file)
        f = CarrierWave::Storage::Uv::File.new(uploader, self, uploader.store_path(identifier))
        f.store(file)
        return f
      end

      # Do something to retrieve the file
      #
      # @param [String] identifier uniquely identifies the file
      #
      # [identifier (String)] uniquely identifies the file
      #
      # === Returns
      #
      # [Uv::Storage::File] the stored file
      #
      def retrieve!(identifier)
        logger.debug "Called retrieve with #{identifier}"

        f = CarrierWave::Storage::Uv::File.new(uploader, self, identifier)

        logger.debug "File created: #{f.uv_file.present?}"

        if f.uv_file.present?
          logger.debug "Uv_File present: #{f.uv_file.present?}"
          uploader.instance_variable_set(:@file, f)
          return f
        else
          logger.debug "File not found"
          return nil
        end
      end

      def logger
        @logger ||= Logger.new("#{RAILS_ROOT}/log/uv_storage.log")
      end

    end # S3
  end # Storage
end # CarrierWave
