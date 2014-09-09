require_relative '../../../data/vulndb'

module Dap
module Filter

module BaseVulnMatch
  def search(hash, service)
    SEARCHES[service].each do | entry |
      entry[:regex].each do | regex, value |
        if regex =~ hash[entry[:hash_key]].force_encoding('BINARY')
          # Handle cases that could be multiple hits, not for upnp but could be others.
          hash[entry[:output_key]] = ( hash[entry[:output_key]] ? hash[entry[:output_key]] + value : value )
        end
      end if hash[entry[:hash_key]]
    end
    hash
  end

  def lookup(hash, service)
    SEARCHES[service].each do | entry |
      if hash[entry[:hash_key]]
        res = entry[:cvemap][hash[entry[:hash_key]]]
        if res
          hash[entry[:output_key]] = res
        end
      end
    end
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

class FilterVulnMatchIPMI
  include Base
  include BaseVulnMatch

  def process(doc)
    doc = search(doc, :ipmi)

    if (doc['data.ipmi_user_non_null'] == "0") && (doc['data.ipmi_user_null'] == "0")
      doc["vulnerability"] = ( doc["vulnerability"] ? doc["vulnerability"] + ["IPMI-ANON"] : ["IPMI-ANON"] )
    end

    [ doc ]
  end
end

class FilterVulnMatchMSSQL
  include Base
  include BaseVulnMatch

  def process(doc)
    doc = lookup(doc, :mssql)
    [ doc ]
  end
end

end
end