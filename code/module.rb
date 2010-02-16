module SMIL
  class Module
    include DataMapper::Resource
    
    property :name,           String, :key => true
    
    has n, :elements,         :model => "SMIL::Element"
    has n, :definitions,      :model => "SMIL::Attribute::Definition"
    has n, :smil_attributes,  :model => "SMIL::Attribute", :through => :definitions
    
    class FunctionalArea
      include DataMapper::Resource
      
      property :name, String, :key => true
      
      has n, :modules, :model => "SMIL::Module"
      has n, :elements, :model => "SMIL::Element", :through => :modules
    end
    
    class Dependency
      include DataMapper::Resource
      property :depender_name, String, :key => true
      property :dependent_name, String, :key => true
      
      belongs_to :dependent, :model => "SMIL::Module"
      belongs_to :depender, :model => "SMIL::Module"
    end
  end
end