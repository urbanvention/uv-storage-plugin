# Require needed libraries
%w{ httpclient json logger fileutils active_support }.each do |lib|
  begin
    require lib
  rescue
    puts "#{lib} not found, please install it with `gem install #{lib}`"
  end
end

require 'active_support/core_ext/object/blank'
require 'uv_storage'

begin
  require 'carrierwave'
rescue => e
  puts 'Carrierwave not loaded.'
end


# Configure CarrierWave if present
if defined?(CarrierWave)
  require 'carrierwave/storage/abstract'
  require 'carrierwave/storage/uv'
  
  CarrierWave.config[:storage_engines].update(:uv_storage => "CarrierWave::Storage::Uv")
  CarrierWave.config[:use_cache] = true
  CarrierWave.config[:cache_to_cache_dir] = true
end

# Load the correct model for the used database backend
if defined?(ActiveRecord)
  require 'uv_storage/orm/active_record'
  require 'uv_storage/file_mapping'
  
  Uv::Storage.orm = Uv::Storage::Orm::ActiveRecord
end

if defined?(DataMapper)
  require 'uv_storage/orm/data_mapper'
  
  Uv::Storage.orm = Uv::Storage::Orm::DataMapper
end

if defined?(Sequel)
  require 'uv_storage/orm/active_record'

  Uv::Storage.orm = Uv::Storage::Orm::Sequel
end

if defined?(Mongoid)
  require 'uv_storage/orm/mongoid'

  Uv::Storage.orm = Uv::Storage::Orm::Mongoid
end
