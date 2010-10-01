require File.dirname(__FILE__) + "/spec_helpers"
include SpecHelperFunctions
setup_database_connection

require File.dirname(__FILE__) + "/../lib/uv_storage"
require File.dirname(__FILE__) + "/fixtures/classes"

RAILS_ROOT = File.dirname(__FILE__) + "/rails_app"

Spec::Runner.configure do |config|
  config.prepend_before(:each) do
    
  end

  config.prepend_after(:each) do
    
  end
end