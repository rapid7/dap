bzcat ssl_certs.bz2 | ../bin/dap json + select host_ip ssl_version port cipher + geoip host_ip + json
