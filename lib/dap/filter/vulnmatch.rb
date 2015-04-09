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

class FilterVulnMatchHTTP
  include Base
  include BaseVulnMatch

  def check_shellshock(doc)
    if not doc["http.headers"]
      return []
    end

    h = doc["http.headers"]
    sspattern = /\(\)\s*{\s*:;\s*};/

    if h["user-agent"] and h["user-agent"] =~ sspattern
      return ['VULN-SHELLSHOCK', 'CVE-2014-6271']
    end

    if h["referrer"] and h["referrer"] =~ sspattern
      return ['VULN-SHELLSHOCK', 'CVE-2014-6271']
    end

    return []
  end

  def check_elastic(doc)
    if not doc['http.path']
      return []
    end
    if not doc['http.path'] == '/_search'
      return []
    end

    input = doc['http.query']
    if doc['http.method'] == "POST"
      input = doc['http.body']
    end

    if not input.match("script_fields")
      return []
    end

    out = ['VULN-ELASTICSEARCH-RCE']
    if (input.match("Runtime") and input.match("getRuntime()")) or
      (input.match("FileOutputStream") and input.match("URLClassLoader"))
      out += ['CVE-2014-3120']
    end

    if input.match("getDeclaredConstructor")
      out += ['CVE-2015-1427']
    end

    if input.match("metasploit.Payload")
      out += ['METASPLOIT']
    end

    return out
  end

  def process(doc)
    vulns = []
    if doc['vulnerability']
      vulns |= doc['vulnerability']
    end

    vulns |= check_elastic(doc)
    vulns |= check_shellshock(doc)

    # see vulndb.rb, allows for simple matches to be added quickly
    SEARCHES[:http].each do | entry |
      success = true

      # all matches must go through
      entry[:match].each do | k, v |
        if not doc[k]
          success = false
        else
          m = doc[k].match(v)
          if not m
            success = false
          end
        end

        if not success
          break
        end
      end

      if success
        vulns |= entry[:cve]
      end
    end

    if vulns
      doc['vulnerability'] = vulns
    end

    [ doc ]
  end
end

end
end