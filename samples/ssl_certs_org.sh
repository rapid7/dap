bzcat ssl_certs.bz2 | ../bin/dap json + select host_ip ssl_version port cipher + geo_ip_org host_ip + json
