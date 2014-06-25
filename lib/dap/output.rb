module Dap
module Output

  require 'oj'

  module FileDestination
    
    attr_accessor :fd

    def open(file_name)
      close
      self.fd = ['-', 'stdout', nil].include?(file_name) ? 
        $stdout : ::File.open(file_name, "wb")
    end

    def close
      self.close if self.fd
      self.fd = nil
    end

    # Overload this to add headers
    def start
    end

    # Overload this to add footers
    def stop
    end

  end


  #
  # Line Output (CSV, TSV, etc)
  # XXX: Quoted field handling is not supported, CSV should be a new output type
  #
  class OutputLines
    
    attr_accessor :fields, :delimiter
    FIELD_WILDCARD = '_'

    include FileDestination

    def initialize(args)
      file = nil
      self.delimiter = ","
      self.fields    = FIELD_WILDCARD
      
      header = false

      args.each do |str|
        k,v = str.split('=', 2)
        case k
        when 'file'
          file = v
        when 'header'
          header = ( v =~ /^[ty1]/i ? true : false )
        when 'fields'
          self.fields = v.split(',')
        when 'delimiter'
          self.delimiter = 
            case v.to_s
            when 'tab'
              "\t"
            when 'null'
              "\x00"
            else
              v
            end
        end
      end
      self.open(file)

      if header and not fields.include?(FIELD_WILDCARD)
        self.fd.puts self.fields.join(self.delimiter)
      end

    end

    def write_record(doc)
      out = []

      if self.fields.include?(FIELD_WILDCARD)
        doc.each_pair do |k,v|
          out << v.to_s
        end
      else
        self.fields.each do |k|
          out << doc[k].to_s
        end
      end

      return unless out.length > 0

      self.fd.puts out.join(self.delimiter)
    end

  end

  #
  # JSON Output (line-delimited records)
  #
  class OutputJSON
    
    include FileDestination

    def initialize(args)
      self.open(args.first)
    end

    def write_record(doc)
      ndoc = {}
      doc.each_pair do |k,v|
        k = k.to_s
        if v.kind_of?(::String)
         ndoc[k] = v.encode(v.encoding, "UTF-8", :invalid => :replace, :undef => :replace, :replace => '')
        end
      end
      self.fd.puts Oj.dump(ndoc)
    end

  end

end
end
