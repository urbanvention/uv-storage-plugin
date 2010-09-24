# Include hook code here
require 'uv_storage'
require 'carrierwave/storage/uv'
require 'uv_storage/file_mapping'

CarrierWave.config[:storage_engines].update(:uv_storage => "CarrierWave::Storage::Uv")
CarrierWave.config[:use_cache] = true
CarrierWave.config[:cache_to_cache_dir] = true