module SpecHelperFunctions
  
  def open_test_file(file = 'test.txt')
    @file = File.new(FIXTURES_PATH + "/#{file}", 'r')
  end
  
  def create_valid_file
    f     = open_test_file
    obj   = Factory(:photo_with_title)
    
    f.should_not      be_nil
    obj.should_not    be_nil
    
    uv_file = Uv::Storage::File.new(f, :object => obj)
    
    uv_file.should_not be_nil
    
    # DEBUG to see exception: uv_file.save
    
    lambda { uv_file.save }.should_not raise_error(Uv::Storage::ApiError)
    
    return [f, obj, uv_file]
  end
  
  def setup_database_connection
    require 'rubygems'
    require 'sqlite3'
    require 'active_record'

    ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => ':memory:'
    ActiveRecord::Migration.verbose = false

    ActiveRecord::Schema.define do
      
      create_table :file_mappings do |t|
        t.column :object_name,        :string
        t.column :object_identifier,  :integer
        t.column :identifier,         :string
        t.column :nodes,              :text
        t.column :file_id,            :integer
        t.column :file_path,          :string
        t.column :access_level,       :string
        t.column :created_at,         :datetime
        t.column :updated_at,         :datetime
      end    

      add_index :file_mappings, :object_name
      add_index :file_mappings, :object_identifier
      add_index :file_mappings, :identifier
      
      create_table :photos do |t|
        t.column :title,              :string
      end
      
      create_table :videos do |t|
        t.column :title,              :string
      end
      
    end

   
  end
  
end