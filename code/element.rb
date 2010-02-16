module SMIL
  class Element
    include DataMapper::Resource
    
    property :name,           String, :key => true

    belongs_to :module,       :model => "SMIL::Module"
    has n, :definitions,      :model => "SMIL::Attribute::Definition"
    has n, :smil_attributes,  :model => "SMIL::Attribute", :through => :definitions
  end
end