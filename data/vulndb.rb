
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
}
