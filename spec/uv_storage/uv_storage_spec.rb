require File.dirname(__FILE__) + "/../spec_helper"

describe Uv::Storage do
  describe "uv_storage_base" do
    
    before(:each) do
      # destroy exisitng object
      Uv::Storage::FileMapping.all.each do |mapping|
        begin
          file = Uv::Storage::File.new(:mapping => mapping)
          file.destroy
        rescue
        end
        
        mapping.delete
      end
      
      Photo.delete_all
    end
    
    it "should initialize a config when initializing a connection" do
      connection = Uv::Storage::Connection.new
      
      connection.config.should_not be_nil
    end
    
    it "should initialize a new file object" do
      file = Uv::Storage::File.new
      
      file.should_not be_nil
    end
    
    it "should not allow calling the api methods without options" do
      file = Uv::Storage::File.new
      
      lambda { file.copy( Factory(:photo_with_title) ) }.should raise_error(Uv::Storage::ApiError)
      lambda { file.read() }.should raise_error(Uv::Storage::ApiError)
      lambda { file.url() }.should raise_error(Uv::Storage::ApiError)
      lambda { file.access_level() }.should raise_error(Uv::Storage::ApiError)
      lambda { file.filename() }.should raise_error(Uv::Storage::ApiError)
      lambda { file.access_level = Uv::Storage::File::ACL_PUBLIC }.should raise_error(Uv::Storage::ApiError)
      lambda { file.destroy() }.should raise_error(Uv::Storage::ApiError)
      lambda { file.content_type() }.should raise_error(Uv::Storage::ApiError)
      lambda { file.size() }.should raise_error(Uv::Storage::ApiError)
      lambda { file.read() }.should raise_error(Uv::Storage::ApiError)
      lambda { file.save() }.should raise_error(Uv::Storage::ApiError)
      lambda { file.nodes() }.should raise_error(Uv::Storage::ApiError)
      lambda { file.identifier() }.should raise_error(Uv::Storage::ApiError)
      lambda { file.path() }.should raise_error(Uv::Storage::ApiError)
    end
    
    it "should not allow to create file without a object" do
      f     = open_test_file
      obj   = Factory(:photo_with_title)
      
      f.should_not      be_nil
      obj.should_not    be_nil
      
      uv_file = Uv::Storage::File.new(f)
      uv_file.should_not be_nil
      
      lambda { uv_file.save }.should raise_error(Uv::Storage::ApiError)
    end
    
    it "should allow to create a new file assigned to a given object" do
      create_valid_file
    end
    
    it "should find an exisiting file based on a object" do
      # first create a valid file
      file, object, uv_file = create_valid_file
      original_size = File.size(file.path)
      original_data = open(file.path) do |f|
        f.read
      end
      original_content_type = MIME::Types.type_for(file.path).first.to_s
      
      # retrieve the file
      lambda { @uv_file = Uv::Storage::File.new(:object => object) }.should_not raise_error(Uv::Storage::ApiError)
      
      @uv_file.url.should_not be_nil
      @uv_file.read.should_not be_nil
      @uv_file.read.should == original_data
      @uv_file.filename.should_not be_nil
      @uv_file.size.should equal(original_size)
      @uv_file.content_type.should_not be_nil
      @uv_file.content_type.should == original_content_type
      @uv_file.nodes.should_not be_nil
      @uv_file.path.should_not be_nil
      @uv_file.access_level.should_not be_nil
      @uv_file.access_level.should == Uv::Storage::File::ACL_PUBLIC
      @uv_file.identifier.should_not be_nil
    end
    
    it "should get the url of an existing file" do
      file, object, uv_file = create_valid_file
      
      uv_file.url.should_not be_nil
    end
    
    it "should read the file contents" do
      file, object, uv_file = create_valid_file
      
      original_data = open(file.path) do |f|
        f.read
      end
      
      uv_file.read.should_not be_nil
      uv_file.read.should == original_data
    end
    
    it "should destroy a file" do
      file, object, uv_file = create_valid_file
      
      lambda { uv_file.destroy }.should_not raise_error(Uv::Storage::ApiError)
    end
    
    it "should retrieve nodes for a file" do
      file, object, uv_file = create_valid_file
      
      lambda { @nodes = uv_file.nodes }.should_not raise_error(Uv::Storage::ApiError)
      
      @nodes.should_not be_nil
    end
    
    it "should get the identifier for a file" do
      file, object, uv_file = create_valid_file
      
      lambda { @identifier = uv_file.identifier }.should_not raise_error(Uv::Storage::ApiError)
      
      @identifier.should_not be_nil
    end
    
    it "should get the path for a existing file"
    it "should read the access level for a file"
    it "should update the access level of a file"
    it "should allow file creation through carrierwave"
    it "should save versions to uv storage"
    it "should update the access level through carrierwave"
    it "should generate a url for a carrierwave file"
    it "should destroy a file through carrierwave"
    it "should respect the dont save option for versions"
    it "should allow uploading of pdf files through carrierwave"
    it "should allow to set encoding settings in carrierwave"
  end
end