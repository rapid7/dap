require_relative '../../../data/vulndb'

module Dap
module Filter

module BaseVulnMatch
  def search(hash, service)
    SEARCHES[service][:regex].each do | regex, value |
      if regex =~ hash[SEARCHES[service][:hash_key]].force_encoding('BINARY')
        # Handle cases that could be multiple hits, not for upnp but could be others.
        hash[SEARCHES[service][:output_key]] = ( hash[SEARCHES[service][:output_key]] ? hash[SEARCHES[service][:output_key]] + value : value )
      end
    end if hash[SEARCHES[service][:hash_key]]
    hash
  end
end

class FilterVulnMatchUPNP
  include Base
  include BaseVulnMatch

  def process(doc)
    doc = search(doc, :upnp)
    [ doc ]
  end
end

end
end