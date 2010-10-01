require File.dirname(__FILE__) + "/../spec_helper"

describe Uv::Storage do
  describe "uv_storage_base" do
    
    it "should initialize a config when initializing a connection" do
      connection = Uv::Storage::Connection.new
      
      connection.config.should_not be_nil
    end
    
  end
end