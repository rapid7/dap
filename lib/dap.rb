module Dap

  require 'bundler/setup'
  
  require 'dap/input'
  require 'dap/output'
  require 'dap/filter'

  class Factory

    @@inputs  = {}
    @@outputs = {}
    @@filters = {}

    def self.create_input(args)
      name = args.shift
      raise RuntimeError, "Invalid input plugin: #{name}" unless @@inputs[name]
      @@inputs[name].new(args)
    end
    
    def self.create_output(args)
      name = args.shift
      raise RuntimeError, "Invalid output plugin: #{name}" unless @@outputs[name]
      @@outputs[name].new(args)
    end

    def self.create_filter(args)
      name = args.shift
      raise RuntimeError, "Invalid filter plugin: #{name}" unless @@filters[name]
      @@filters[name].new(args)
    end

    #
    # Create nice-looking filter names from classes
    # Ex: FilterHTTPDecode => http_decode
    # Ex: FilterLimitLen => limit_len
    #
    def self.name_from_class(name)
      name.to_s.split('::').last.
      gsub(/([A-Z][a-z])/) { |c| "_#{c[0,1].downcase}#{c[1,1]}" }.
      gsub(/([a-z][A-Z])/) { |c| "#{c[0,1]}_#{c[1,1].downcase}" }.
      gsub(/_+/, '_').
      sub(/^_(input|filter|output)_/, '').downcase
    end
    
    #
    # Load input formats
    #
    def self.load_inputs
      Dap::Input.constants.each do |c|
        next unless c.to_s =~ /^Input/
        o = Dap::Input.const_get(c)
        @@inputs[ name_from_class(c) ] = o
      end
    end

    #
    # Load output formats
    #
    def self.load_outputs
      Dap::Output.constants.each do |c|
        o = Dap::Output.const_get(c)
        next unless c.to_s =~ /^Output/
        @@outputs[ name_from_class(c) ] = o        
      end      
    end

    #
    # Load filters
    #
    def self.load_filters
      Dap::Filter.constants.each do |c|
        o = Dap::Filter.const_get(c)
        next unless c.to_s =~ /^Filter/
        @@filters[ name_from_class(c) ] = o        
      end
    end

    def self.inputs
      @@inputs
    end

    def self.outputs
      @@outputs
    end

    def self.filters
      @@filters
    end    

    def self.load_modules
      self.load_inputs
      self.load_outputs
      self.load_filters
    end
  end

  Factory.load_modules

end