# PanOS API-based model for Oxidized - LOCAL AND PANORAMA-PUSHED CONFIGS
#
# This model retrieves both local and Panorama-pushed configurations
# in both dict format and XML format.
# Make sure to use the "http" input for this module.
begin
  require 'nokogiri'
  require 'tempfile'
rescue LoadError
  raise Oxidized::OxidizedError, 'nokogiri not found: sudo gem install nokogiri'
end

class PanOS_API < Oxidized::Model # rubocop:disable Naming/ClassAndModuleCamelCase
  using Refinements
  
  cfg_cb = lambda do
    url_param = URI.encode_www_form(
      user:     @node.auth[:username],
      password: @node.auth[:password],
      type:     'keygen'
    )
    kg_r = get_http "/api?#{url_param}"
    
    # Parse the XML API response for the keygen request.
    kg_x = Nokogiri::XML(kg_r)
    
    # Check if keygen was successful. If not we'll throw an error.
    status = kg_x.xpath('//response/@status').first
    if status.to_s != 'success'
      msg = kg_x.xpath('//response/result/msg').text
      raise Oxidized::OxidizedError, "Could not generate PanOS API key: #{msg}"
    end
    
    # Get the API key from the keygen response
    apikey = kg_x.xpath('//response/result/key').text.to_s
    
    # First, get local XML configuration
    url_param_xml = URI.encode_www_form(
      key:      apikey,
      category: 'configuration',
      type:     'export'
    )
    cfg_xml_local = get_http "/api?#{url_param_xml}"
    xml_local_formatted = Nokogiri::XML(cfg_xml_local).to_xml(indent: 2)
    
    # Second, get Panorama-pushed template configuration
    op_cmd_template = '<show><config><pushed-template></pushed-template></config></show>'
    url_param_template = URI.encode_www_form(
      key:  apikey,
      type: 'op',
      cmd:  op_cmd_template
    )
    cfg_xml_template = get_http "/api?#{url_param_template}"
    
    # Parse template response
    template_xml = Nokogiri::XML(cfg_xml_template)
    
    # Convert local XML to dict format
    set_commands_local = ""
    begin
      temp_xml = Tempfile.new(['panos_config_local', '.xml'])
      temp_xml.write(cfg_xml_local)
      temp_xml.close
      
      set_output = `/usr/local/bin/panos_xml_to_set.py #{temp_xml.path} 2>&1`
      
      if $?.success?
        set_commands_local = set_output
      else
        set_commands_local = "# Error converting local XML:\n# #{set_output}"
      end
      
      temp_xml.unlink
    rescue => e
      set_commands_local = "# Error: #{e.message}"
    end
    
    # Convert Panorama template XML to dict format and filter for network.virtual-router only
    set_commands_panorama = ""
    begin
      temp_xml_pano = Tempfile.new(['panos_config_panorama', '.xml'])
      # Extract template result
      template_result = template_xml.xpath('//result').to_xml
      
      temp_xml_pano.write(template_result)
      temp_xml_pano.close
      
      set_output_pano = `/usr/local/bin/panos_xml_to_set.py #{temp_xml_pano.path} 2>&1`
      
      if $?.success?
        # Filter for only network.virtual-router entries
        filtered_lines = set_output_pano.split("\n").select do |line|
          line.include?('network.virtual-router')
        end
        set_commands_panorama = filtered_lines.join("\n")
        
        if set_commands_panorama.empty?
          set_commands_panorama = "# No network.virtual-router configuration found in Panorama template"
        end
      else
        set_commands_panorama = "# Error converting Panorama XML:\n# #{set_output_pano}"
      end
      
      temp_xml_pano.unlink
    rescue => e
      set_commands_panorama = "# Error: #{e.message}"
    end
    
    # Combine all formats with clear separators
    output = "############################################\n"
    output += "# LOCAL CONFIGURATION (Dict Format)\n"
    output += "############################################\n\n"
    output += set_commands_local
    output += "\n\n"
    output += "############################################\n"
    output += "# PANORAMA-PUSHED TEMPLATE - VIRTUAL ROUTER ONLY (Dict Format)\n"
    output += "############################################\n\n"
    output += set_commands_panorama
    output += "\n\n"
    output += "############################################\n"
    output += "# LOCAL CONFIGURATION (XML Format)\n"
    output += "############################################\n\n"
    output += xml_local_formatted
    
    output
  end
  
  cmd cfg_cb
  
  cfg :http do
    # Palo Alto's API always requires HTTPS
    @secure = true
  end
end
