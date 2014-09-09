# -*- coding: binary -*-
module Dap
module Proto
module MSSQL

  #
  # Data condensed from http://sqlserverbuilds.blogspot.com/
  # Given a version like 8.00.2039, this data structure allows
  # us to determine that the year version is 2000 sp4.
  # The version_num_to_name method implements this conversion.
  #
  MSSQL_VERSIONS = {
      '7.00'=> {
          :year=>'7.0',
          :service_packs=> {
              623=>'-',
              699=>'sp1',
              842=>'sp2',
              961=>'sp3',
              1063=>'sp4'
          }
      },
      '8.00'=> {
          :year=>'2000',
          :service_packs=> {
              194=>'-',
              384=>'sp1',
              534=>'sp2',
              760=>'sp3',
              2039=>'sp4'
          }
      },
      '9.00'=> {
          :year=>'2005',
          :service_packs=> {
              1399=>'-',
              2047=>'sp1',
              3042=>'sp2',
              4035=>'sp3',
              5000=>'sp4'
          }
      },
      '10.00'=> {
          :year=>'2008',
          :service_packs=> {
              1600=>'-',
              2531=>'sp1',
              4000=>'sp2',
              5500=>'sp3'
          }
      },
      '10.50'=> {
          :year=>'2008',
          :service_packs=> {
              1600=>'r2',
              2500=>'r2 sp1',
              4000=>'r2 sp2'
          }
      },
      '11.00'=> {
          :year=>'2012',
          :service_packs=> {
              2100=>'-',
              3000=>'sp1'
          }
      },
      '12.00'=> {
          :year=>'2014',
          :service_packs=> {
              2000=>'-'
          }
      }
  }

  #
  # Given a XX.YY.ZZ[.AA] version, will attempt to get the sql server
  # year/service pack version for it.
  def self.version_num_to_name(version)
    rx  = /(\d+)\.(\d+)\.(\d+).*/
    if version =~ rx
      v1 = $1.to_i
      v2 = $2.to_i
      v3 = $3.to_i
    else
      return [ nil, nil ]
    end
    #puts("v1=#{v1}, v2=#{v2}, v3=#{v3}")
    key = sprintf("%d.%02d",v1,v2)
    svc_pack = nil
    year = nil
    if MSSQL_VERSIONS[key]
      year = MSSQL_VERSIONS[key][:year]
      svc_packs = MSSQL_VERSIONS[key][:service_packs]
      is_first=true
      svc_packs.each do | k, v|
        #puts( "k=#{k}, v=#{v}")
        if v3 <= k and is_first
          svc_pack = v
          break
        elsif v3 == k
          svc_pack = v
          break
        else
          svc_pack = v
        end
        is_first=false
      end
    end
    [ year, svc_pack]
  end

end
end
end
