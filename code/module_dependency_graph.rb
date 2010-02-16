require 'rubygems'
require 'nokogiri'
require 'open-uri'

standard_link = "/Users/knowtheory/Books and Articles/SMIL/smil30.html"
@standard = Nokogiri::HTML(open(standard_link))

def module_svg
  @module_dependencies = fetch_module_dependencies(@standard)

  @functional_groups = fetch_functional_groups(@standard)

  @has_optional_dependencies = ["MultiArcTiming", "FillDefault", "SyncBehavior", "TransitionModifiers"]
  @colors = [ "lightskyblue", "mediumturquoise", "lawngreen", "orchid",
              "lightgoldenrod", "indianred1", "moccasin", "snow",
              "salmon", "rosybrown", "violetred1", "honeydew2"]

  @color_map = {}
  @colors.sort_by{ rand }.zip(@functional_groups.keys.sort_by{rand}).each{ |c,g| @color_map[g] = c}
  
  labeled_rectangle = <<-LabledRectangle
<g id="#{id}">
  <rect x="#{x}" y="#{y}" width="#{width}" height="#{36}" fill="#{color}" stroke="black" stroke-width="1"/>
  <text transform="translate(#{x+5} #{y+10})" fill="black">
    <tspan font-size="12" font-weight="500" x=".4658203" y="11">#{name}</tspan>
  </text>
</g>
  LabledRectangle
  
end

def module_graphviz
  @module_dependencies = fetch_module_dependencies(@standard)

  @functional_groups = fetch_functional_groups(@standard)

  @has_optional_dependencies = ["MultiArcTiming", "FillDefault", "SyncBehavior", "TransitionModifiers"]
  @colors = [ "lightskyblue", "mediumturquoise", "lawngreen", "orchid",
              "lightgoldenrod", "indianred1", "moccasin", "snow",
              "salmon", "rosybrown", "violetred1", "honeydew2"]

  @color_map = {}
  @colors.sort_by{ rand }.zip(@functional_groups.keys.sort_by{rand}).each{ |c,g| @color_map[g] = c}
  
  @cluster_counter = 0
  puts "digraph SMILModules {"
  puts "  compound=true;"
  @functional_groups.each do |group, modules|
    puts "  subgraph cluster#{@cluster_counter} {"
    puts "\t\tlabel=\"#{group}\";"
    puts "\t\tfontsize=18;"
    modules.each{ |m| puts "\t\t#{m} [shape=box] [fillcolor=#{@color_map[group]}]"}
    print "\t}"
    @cluster_counter += 1
  end
  puts
  @module_dependencies.map do |k,v|
    if v
      v.each do |dep| 
        connection = "  #{k} -> #{dep}"
        connection += " [style=dashed]" if @has_optional_dependencies.include? k
        puts connection
      end
    end
  end
  puts "}"
end

def fetch_functional_groups(standard)
  functional_groups = {}
  standard.xpath("//a[@name='smil-modules-smilModulesNSSMILModules']/parent::h2").
    xpath("following-sibling::div[1]/ol[1]/li").map do |n| 
      group, *members = n.text.gsub(/\(\*+\)/,"").split
      functional_groups[group] = members
    end
  functional_groups
end

def fetch_module_dependencies(standard)
  module_dependencies = {}
  standard.xpath("//a[@name='smil-modules-smilModulesNSSMILModules']/parent::h2"). # h2 of section 2.4
            xpath("following-sibling::div[1]/table"). # dependency table 1 in section 2.4
            xpath("tbody/tr")[1..-1]. # get all but the first row
            each do |tr| 
              cells = tr.css("td")
              module_name = cells.first.text.gsub("MetaInformation","Metainformation").gsub("MediaRenderAtrributes","MediaRenderAttributes")
              dependencies = cells.last.text.gsub("BasicExclTimeContiners", "BasicExclTimeContainers").gsub(/\s+(and\/or|and|or)\s+|\s+/,"").split(",")
              module_dependencies[module_name] = dependencies == ["NONE"] ? nil : dependencies
            end
  module_dependencies
end

#module_graphviz