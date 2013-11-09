module Dap
module Input

  require 'oj'
  
  #
  # Error codes for failed reads
  # 
  module Error
    EOF   = :eof
    Empty = :empty
  end

  module FileSource
    
    attr_accessor :fd

    def open(file_name)
      close
      self.fd = ['-', 'stdin', nil].include?(file_name) ? 
        $stdin : ::File.open(file_name, "rb")
    end

    def close
      self.close if self.fd
      self.fd = nil
    end
  end

  #
  # Line Input
  #
  class InputLines
    
    include FileSource

    def initialize(args)
      self.open(args.first)
    end

    def read_record
      line = self.fd.readline rescue nil
      return Error::EOF unless line
      { 'line' => line.chomp("\n") }
    end

  end

  #
  # JSON Input (line-delimited records)
  #
  class InputJSON
    
    include FileSource

    def initialize(args)
      self.open(args.first)
    end

    def read_record  
      line = self.fd.readline rescue nil
      return Error::EOF unless line
      json = Oj.load(line.strip) rescue nil
      return Error::Empty unless json
      json
    end

  end

end
end