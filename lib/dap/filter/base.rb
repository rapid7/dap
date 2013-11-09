module Dap
module Filter

module Base
  attr_accessor :name, :opts

  def initialize(args)
    self.opts = {}
    args.each do |arg|
        k,v = arg.split("=", 2)
        self.opts[k] = v
    end
  end

  def process(doc)
    raise RuntimeError, "No process() method defined for filter"
  end

end

end
end