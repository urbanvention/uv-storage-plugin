FIXTURES_PATH = File.dirname(__FILE__) + "/fixtures"

require File.dirname(__FILE__) + "/spec_helpers"

include SpecHelperFunctions
setup_database_connection

require 'rubygems'
require 'factory_girl'
require 'mime/types'

require File.dirname(__FILE__) + "/fixtures/classes"
require 'factories'

RAILS_ROOT = File.dirname(__FILE__) + "/rails_app"

Spec::Runner.configure do |config|
  config.prepend_before(:each) do
    
  end

  config.prepend_after(:each) do
    
  end
end

require File.dirname(__FILE__) + "/../lib/uv_storage"