# Include hook code here
require 'uv_storage'
require 'carrierwave/uv_storage'
require 'uv_storage/file_mapping'

CarrierWave.config[:storage_engines].update(:uv_storage => "Uv::Storage::CarrierWave")