# encoding: utf-8
begin
  require 'uv_storage'
  require 'carrierwave/storage/abstract'
rescue LoadError
  raise "UV Storage not available"
end

module Uv
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
    class CarrierWave < CarrierWave::Storage::Abstract

      class StorageFile
        
        attr_accessor :object
        attr_accessor :uv_file
        
        def initialize(uploader, base, path)
          puts 'New carrier wave file'
          
          @uploader = uploader
          @path = path
          @base = base
          @object = @uploader.model
          
          # try to find an existing file
          @object.save_without_validation if @object.new_record?
          
          if @object.present?
            mapping = Uv::Storage::FileMapping.find_by_object_name_and_object_identifier(@object.class.to_s.downcase.to_s, @object.id)
            @uv_file = Uv::Storage::StorageFile.new(:file_mapping => mapping)
          else
            puts 'no object present'
          end
        end

        ##
        # Returns the current path of the file on Uv::Storage
        #
        # === Returns
        #
        # [String] A path
        #
        def path
          @uv_file.path
        end

        ##
        # Reads the contents of the file from Uv::Storage
        #
        # === Returns
        #
        # [String] contents of the file
        #
        def read
          @uv_file.read
        end

        ##
        # Remove the file from Uv::Storage
        #
        def delete
          @uv_file.destroy
        end

        ##
        # Returns the url on Uv::Storage service
        #
        # === Returns
        #
        # [String] file's url
        #
        def url(expires = nil)
          @uv_file.url(expires)
        end

        def store(file)
          puts "Storing File in Object: #{file.class}"
          puts "Sanitized file #{file.original_filename} / #{file.file.class}"
          
          f = File.open("#{RAILS_ROOT}/tmp/#{file.original_filename}", "w+")
          f.write file.read
            
          puts "Saved File #{f.class} / #{File.basename(f.path)}"

          @uv_file = Uv::Storage::StorageFile.new(f, :object => @object)
          
          begin
            @uv_file.save
          rescue Exception => e
            puts "Error saving file #{e.inspect}"
          end
        end

        # The Amazon S3 Access policy ready to send in storage request headers.
        def access_policy
          @uv_file.access_level
        end

        def content_type
          @uv_file.content_type
        end

        def content_type=(type)
          # 
        end

        def size
         	@uv_file.size
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
        f = Uv::Storage::CarrierWave::StorageFile.new(uploader, self, uploader.store_path(identifier))
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
        puts 'Called retrieve with ' + identifier.to_s
        f = Uv::Storage::CarrierWave::StorageFile.new(uploader, self, identifier)
        uploader.instance_variable_set(:@file, f)
        return f
      end

    end # S3
  end # Storage
end # CarrierWave
