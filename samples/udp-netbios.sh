bzcat udp-netbios.csv.bz2 | ../bin/dap csv - header=y + select saddr data + rename saddr=ip + transform data=hexdecode + decode_netbios_status_reply data + remove data + json 
