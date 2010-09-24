class CreateFileMappings < ActiveRecord::Migration
  def self.up
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
  end

  def self.down
    remove_index :file_mappings, :identifier
    remove_index :file_mappings, :object_identifier
    remove_index :file_mappings, :object_name
    
    drop_table :file_mappings
  end
end