module Dap
module Input

  require 'csv'

  #
  # CSV
  #
  class InputCSV

    include FileSource

    def initialize(args)
      self.open(args.first)
    end

    def read_record
      res = {}
      line = self.fd.readline rescue nil
      return Error::EOF unless line
      arr = CSV.parse(line) rescue nil
      return Error::Empty unless arr
      cnt = 0
      arr.first.each do |x|
        cnt += 1
        if x.to_s.length > 0
          res[cnt.to_s] = x
        end
      end
      res
    end

  end

end
end