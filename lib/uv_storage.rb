require 'logger'
require 'uv_storage/config'
require 'uv_storage/file'
require 'uv_storage/connection'
require 'uv_storage/encoding_com/base'
require 'app/models/uv_storage/file_mapping'

module Uv #:nodoc:
  module Storage #:nodoc:
    
    # 
    # The asset domain used for building the node urls
    # An example for such an url, based on the asset domain 'urbanclouds.com', will look like this:
    # 
    #   sdfw44tf.urbanclouds.com  # the subdomain hash will be pretended automaticly to the asset domain
    # 
    mattr_accessor :asset_domain
    @@asset_domain = 'urbanclouds.com'
    
    # 
    # The master domain is used for the communication with Uv::Storage cloud. If you don't know what you are doing,
    # you should not change this url.
    # 
    mattr_accessor :master_domain
    @@master_domain = 'master.urbanclouds.com'
    
    # 
    # Currently not supported, used for ssl switch for domains.
    # 
    mattr_accessor :use_ssl
    @@use_ssl       = false
    
    mattr_accessor :log_level
    @@log_level     = Logger::DEBUG
    
    mattr_accessor :logger
    mattr_accessor :orm
    
    # 
    # Configuration method, which allows you to set different configuration option through a block in a file in your
    # initializers folder. An example would like this:
    # 
    # Example:
    #     
    #   Uv::Storage.config do |u|
    #     u.asset_domain = 'thecloud.com'
    #     u.master_domain = 'thecloud.com'
    #   end
    # 
    def self.config
      yield self
    end
    
    def self.logger
      @@logger        ||= Logger.new("#{::File.dirname(__FILE__) + '/..'}/log/uv_storage.log")
      @@logger.level  = Logger::DEBUG
      return @@logger
    end
    
    class ApiError < StandardError; end;
    
    class MetaInformationMissing < ApiError; end;
    class MissingFileMapping < ApiError; end;
    class FileObjectMissing < ApiError; end; 
    class NodesMissing < ApiError; end;
    class ActiveRecordObjectMissing < ApiError; end;
    class ActiveRecordObjectInvalid < ApiError; end;
    class NodeConnectionFailed < ApiError; end;
    class MasterConnectionFailed < ApiError; end;
    class MissingSignature < ApiError; end;
    class KeyVerificationFailed < ApiError; end;
    
  end
end