class UvStorageGenerator < Rails::Generator::Base
  
  def manifest
    record do |m|
      m.file 'config.yml', "config/uv_storage.yml"
      m.migration_template "create_file_mappings.rb", "db/migrate"
    end
  end
  
  def file_name
    "create_file_mappings"
  end
  
end