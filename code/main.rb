require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'extlib'
require 'dm-core'
require 'dm-aggregates'
require 'dm-serializer'
require 'attribute'
require 'element'
require 'module'

DataMapper::Logger.new(STDOUT, :debug)
#DataMapper.setup(:default, "mysql://localhost/smil_reference")
DataMapper.setup(:default, "sqlite3:smil_reference.db")
DataMapper.auto_migrate!

standard_link = "../smil30.html"
@standard = Nokogiri::HTML(open(standard_link))

# Create Functional Groups, and Modules
@functional_groups = {}
@standard.xpath("//a[@name='smil-modules-smilModulesNSSMILModules']/parent::h2").
  xpath("following-sibling::div[1]/ol[1]/li").map do |n| 
    group, *members = n.text.strip.split("\n").map{|o|o.gsub(/\(\*+\)/,"").strip}
    @functional_groups[group] = members.reject{|str|str.empty?}
    fa = SMIL::Module::FunctionalArea.create(:name=>group)
    members.reject{|str|str.empty?}.each{|mod| fa.modules.create(:name=>mod) }
  end

@module_dependencies = {}
@standard.xpath("//a[@name='smil-modules-smilModulesNSSMILModules']/parent::h2"). # h2 of section 2.4
          xpath("following-sibling::div[1]/table"). # dependency table 1 in section 2.4
          xpath("tbody/tr")[1..-1]. # get all but the first row
          each do |tr| 
            cells = tr.css("td")
            module_name = cells.first.text.gsub("MetaInformation","Metainformation").gsub("MediaRenderAtrributes","MediaRenderAttributes")
            dependencies = cells.last.text.gsub("BasicExclTimeContiners", "BasicExclTimeContainers").gsub(/\s+(and\/or|and|or)\s+|\s+/,"").split(",")
            @module_dependencies[module_name] = dependencies == ["NONE"] ? nil : dependencies
          end

# Get the Module index, extract the link text, which are module names.
raise "your module lists don't match" unless @standard.xpath("//h1[@id='smil-modules-index-modules-NS']/following::table[position()=1]").css("a").map{|a|a.text.gsub(/\s+/,"")}.sort == @functional_groups.values.flatten.uniq.sort

# Get the all of the element definitions AFTER the table of contents, 
# look for the h2 that precedes each definition, and assume that's the module it belongs to.
@elemod = {}
@standard.xpath("//div[@class='toc'][position()=last()]/following::span[@class='edef']").map do |edef| 
  @elemod[edef.text] = edef.xpath("preceding::h2[1]").text.match(/(\w+)\s(Module|Elements)/).to_a[1]
end

#  We know that the Timing and Synchonization section is structured differently, so we must patch
#  element definitions from that section.

#  The following section gets the index for the Timing and Synchronization section of the SMIL Standard.
#  The index is made of a set of nested definition lists (which thankfully has a regular structure).
@standard.xpath("//h2[@id='smil-timing-Timing-Appendix-Modules']").
          xpath("following::dl[1]/dd/dl/dt[text()='Included features']/following::dd[1]").css(".einst").
          map{ |einst| @elemod[einst.text] = einst.xpath("ancestor::dl/preceding::dt[1]").last.text }

@elemod.keys.each{ |element| SMIL::Module.first(:name=>@elemod[element]).elements.create(:name=>element) }

# Get all the attributes in smil and stick them into the DB.
@attributes = {}
@standard.xpath("//h1[@id='smil-attributes-index-attributes-NS']/following-sibling::table[position()=1]").first.css("tr")[1..-1].map{ |tr| sattr, smod = tr.css("td a").to_a.map{|td|td.text.gsub(/\s+/," ").gsub(/\[|\]|\s+$|SMIL 3\.0 /,"")} }.each{ |sattr, smod| @attributes[smod] ? @attributes[smod] << sattr : @attributes[smod] = [sattr]}

@attributes.values.flatten.sort.uniq.each{|attribute| SMIL::Attribute.create(:name=>attribute)}

SMIL::Element.create(:name=>"*", :module_name => "*") # A meta element for attaching attributes to.

@basic_media_elements = SMIL::Module.first(:name=>"BasicMedia").elements.map{|e|e.name}
@media_and_layout_elements = SMIL::Module::FunctionalArea.all(:name=>["Media Objects","Layout"]).elements.map{|e|e.name}

@attribute_map = {
"Structure"             => {"smil"=>["class", "id", "title", "xml:id", "xml:lang", "xml:[:/prefix/]"],  
                            "head"=>["class", "id", "title", "xml:id", "xml:lang"],
                            "body"=>["class", "id", "title", "xml:id", "xml:lang"],
                            "*"   =>["class", "id", "title", "xml:id", "xml:lang"]},
"Identity"              => {"smil"=>["version", "baseProfile"]},
"BasicMedia"            => Hash[@basic_media_elements.zip([["src", "type"]]*@basic_media_elements.size)],
                            # the paramGroup attribute is applicable to all the elements 
                            # in the Media Objects and Layout functional areas
"MediaParam"            => Hash[@media_and_layout_elements.zip([["paramGroup"]]*@media_and_layout_elements.size)].
                              merge({"param" =>["name","value","valuetype","type"]}),
"MediaRenderAttributes" => Hash[@media_and_layout_elements.zip(
                              [["erase", "mediaRepeat", "sensitivity"]]*@media_and_layout_elements.size)],
"MediaOpacity"          => Hash[@media_and_layout_elements.zip(
                              [["chromaKey", "chromaKeyOpacity", "chromaKeyTolerance",
                                "mediaOpacity", "mediaBackgroundOpacity"]]*@media_and_layout_elements.size)],
"MediaClipping"         => {"audio"=>["clipBegin", "clipEnd"],
                            "textstream"=>["clipBegin", "clipEnd"],
                            "video"=>["clipBegin", "clipEnd"]},
"MediaClipMarkers"      => {},
"BrushMedia"            => {"brush"=>["color"]},
"MediaAccessibility"    => Hash[@media_and_layout_elements.zip(
                              [["alt","longdesc","readIndex"]]*@media_and_layout_elements.size)],
"MediaDescription"      => {"*"=>{"author", "copyright", "title", "xml:lang"}},
"MediaPanZoom"          => Hash[@basic_media_elements.zip([["panZoom"]]*@basic_media_elements.size)].
                              merge({"region"=>["panZoom"]})
}

@optional_attributes = {
  "Identity"  => {"*"=>["version", "baseProfile"]}
}

@deprecated_attributes = {
  "Structure"          => {"smil"=>["id"], "head"=>["id"], "body"=>["id"]},
  "MediaClipping"      => {"*" => ["clip-begin", "clip-end"]},
  "MediaDescription"   => {"*" => ["abstract"]}
}
