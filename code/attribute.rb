module SMIL
  class Attribute
    include DataMapper::Resource
    property :name, String, :key => true
    
    has n, :definitions,  :model => "SMIL::Attribute::Definition"
    has n, :modules,      :model => "SMIL::Module", :through => :definitions
  end
end

module SMIL
  class Attribute
    class Definition
      include DataMapper::Resource
      
      property :id,             Serial
      property :module_name,    String, :required => true
      property :element_name,   String, :required => true
      property :smil_attribute_name, String

      belongs_to :module, :model => "SMIL::Module", :key => true
      belongs_to :element, :model => "SMIL::Element", :key => true
      belongs_to :smil_attribute, :model => "SMIL::Attribute", :key => true
    end
  end
end