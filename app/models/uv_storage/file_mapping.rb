require 'active_record/base'

module Uv
  module Storage
    
    class FileMapping < ActiveRecord::Base
      serialize :nodes
      
      validates_presence_of :object_name
      validates_presence_of :object_identifier
      validates_presence_of :nodes
      #validates_presence_of :file_id
      validates_presence_of :file_path
      validates_presence_of :access_level
    end
    
  end
end