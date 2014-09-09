
# Searches contains each of the services, within each service it contains
# a hash key that will be compared against each of the items in the
# regex hash, and if a hit is returned the value from the regex is inserted
# into the hash with the output_key as the key.
#
SEARCHES = {
    :upnp => [{
      :hash_key   => 'data.upnp_server',
      :output_key => 'vulnerability',
      :regex      => {
        /MiniUPnPd\/1\.0([\.\,\-\~\s]|$)/mi     => ['CVE-2013-0229'],
        /MiniUPnPd\/1\.[0-3]([\.\,\-\~\s]|$)/mi => ['CVE-2013-0230'],
        /Intel SDK for UPnP devices.*|Portable SDK for UPnP devices(\/?\s*$|\/1\.([0-5]\..*|8\.0.*|(6\.[0-9]|6\.1[0-7])([\.\,\-\~\s]|$)))/mi => ['CVE-2012-5958', 'CVE-2012-5959']
      }
    }],

    :ipmi => [{
        :hash_key   => 'data.ipmi_compat_password',
        :output_key => 'vulnerability',
        :regex      => {
            /1/ => ['IPMI-STRAIGHT-PASS'],
        }
    },{
        :hash_key   => 'data.ipmi_compat_md2',
        :output_key => 'vulnerability',
        :regex      => {
            /1/ => ['IPMI-MD2'],
        }
    },{
        :hash_key   => 'data.ipmi_compat_none',
        :output_key => 'vulnerability',
        :regex      => {
            /1/ => ['IPMI-NOAUTH'],
        }
    },{
        :hash_key   => 'data.ipmi_user_disable_message_auth',
        :output_key => 'vulnerability',
        :regex      => {
            /1/ => ['IPMI-PERMSG'],
        }
    },{
        :hash_key   => 'data.ipmi_user_disable_user_auth',
        :output_key => 'vulnerability',
        :regex      => {
            /1/ => ['IPMI-USRLVL'],
        }
    }],

    :mssql => [{
        :hash_key   => 'data.version.name',
        :output_key => 'vulnerability',
        :cvemap     => {
            #['', ''] => ['CVE-2007-5090'],
            ['2000', '-'] => ['CVE-2003-0230', 'CVE-2003-0231', 'CVE-2003-0232', 'CVE-2008-4110', 'CVE-2008-5416'],
            #['2000', '""'] => ['CVE-2003-0230', 'CVE-2003-0231', 'CVE-2003-0232'],
            ['2000', 'sp1'] => ['CVE-2003-0230', 'CVE-2003-0231', 'CVE-2003-0232'],
            ['2000', 'sp2'] => ['CVE-2003-0230', 'CVE-2003-0231', 'CVE-2003-0232'],
            ['2000', 'sp3'] => ['CVE-2003-0230', 'CVE-2003-0231', 'CVE-2003-0232'],
            ['2000', 'sp3a'] => ['CVE-2003-0230', 'CVE-2003-0231', 'CVE-2003-0232'],
            ['2000', 'sp4'] => ['CVE-2008-0085', 'CVE-2008-0086', 'CVE-2008-0106', 'CVE-2008-0107', 'CVE-2012-0158', 'CVE-2012-1856'],
            ['2005', '-'] => ['CVE-2008-5416'],
            ['2005', 'sp1'] => ['CVE-2008-0085', 'CVE-2008-0107'],
            ['2005', 'sp2'] => ['CVE-2007-4814', 'CVE-2007-5348', 'CVE-2008-0085', 'CVE-2008-0086', 'CVE-2008-0106', 'CVE-2008-0107', 'CVE-2008-3012', 'CVE-2008-3013', 'CVE-2008-3014', 'CVE-2008-3015', 'CVE-2009-2500', 'CVE-2009-2501', 'CVE-2009-2502', 'CVE-2009-2503', 'CVE-2009-2504', 'CVE-2009-2518', 'CVE-2009-2528', 'CVE-2009-3126'],
            ['2005', 'sp3'] => ['CVE-2009-2500', 'CVE-2009-2501', 'CVE-2009-2502', 'CVE-2009-2503', 'CVE-2009-2504', 'CVE-2009-2518', 'CVE-2009-2528', 'CVE-2009-3126', 'CVE-2011-1280'],
            ['2005', 'sp4'] => ['CVE-2011-1280', 'CVE-2012-0158', 'CVE-2012-1856', 'CVE-2012-2552'],
            ['2008', 'r2'] => ['CVE-2011-1280', 'CVE-2012-0158', 'CVE-2012-1856'],
            ['2008', 'r2 sp1'] => ['CVE-2012-1856', 'CVE-2012-2552'],
            ['2008', 'r2 sp2'] => ['CVE-2012-1856', 'CVE-2014-4061'],
            ['2008', 'sp1'] => ['CVE-2011-1280'],
            ['2008', 'sp2'] => ['CVE-2011-1280', 'CVE-2012-0158', 'CVE-2012-1856', 'CVE-2012-2552'],
            ['2008', 'sp3'] => ['CVE-2012-0158', 'CVE-2012-1856', 'CVE-2012-2552', 'CVE-2014-4061'],
            ['2012', '-'] => ['CVE-2012-2552'],
            ['2012', 'sp1'] => ['CVE-2014-1820', 'CVE-2014-4061'],
            ['2014', '-'] => ['CVE-2014-1820'],
            ['7.0', '-'] => ['CVE-2003-0230', 'CVE-2003-0231', 'CVE-2003-0232', 'CVE-2004-1560'],
            ['7.0', 'sp1'] => ['CVE-2003-0230', 'CVE-2003-0231', 'CVE-2003-0232', 'CVE-2004-1560'],
            ['7.0', 'sp2'] => ['CVE-2003-0230', 'CVE-2003-0231', 'CVE-2003-0232', 'CVE-2004-1560'],
            ['7.0', 'sp3'] => ['CVE-2003-0230', 'CVE-2003-0231', 'CVE-2003-0232', 'CVE-2004-1560'],
            ['7.0', 'sp4'] => ['CVE-2003-0230', 'CVE-2003-0231', 'CVE-2003-0232', 'CVE-2004-1560', 'CVE-2008-0085', 'CVE-2008-0086', 'CVE-2008-0106', 'CVE-2008-0107'],
        }
    }],
}
