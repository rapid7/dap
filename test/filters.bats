#!/usr/bin/env bats

load ./test_common

@test "rename" {
  run bash -c 'echo world | $DAP_EXECUTABLE lines + rename line=hello + json'
  assert_success
  assert_output '{"hello":"world"}'
}

@test "not_exists" {
  run bash -c "echo '{\"foo\":\"bar\"}' | $DAP_EXECUTABLE json + not_exists foo + json"
  assert_success
  assert_output ''
  run bash -c "echo '{\"bar\":\"bar\"}' | $DAP_EXECUTABLE json + not_exists foo + json"
  assert_success
  assert_output '{"bar":"bar"}'
}

@test "split_comma" {
  run bash -c "echo '{\"foo\":\"bar,baz\"}' | $DAP_EXECUTABLE json + split_comma foo + json | jq -Sc ."
  assert_success
  assert_line --index 0 '{"foo":"bar,baz","foo.word":"bar"}'
  assert_line --index 1 '{"foo":"bar,baz","foo.word":"baz"}'
}

@test "field_split_line" {
  run bash -c "echo '{\"foo\":\"bar\nbaz\"}' | $DAP_EXECUTABLE json + field_split_line foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":"bar\nbaz","foo.f1":"bar","foo.f2":"baz"}'
}

@test  "not_empty" {
  # only exists in godap currently
  skip
  run bash -c "echo '{\"foo\":\"bar,baz\"}' | $DAP_EXECUTABLE json + not_empty foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":"bar,baz"}'
}

@test "field_split_tab" {
  run bash -c "echo '{\"foo\":\"bar\tbaz\"}' | $DAP_EXECUTABLE json + field_split_tab foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":"bar\tbaz","foo.f1":"bar","foo.f2":"baz"}'
}

@test "truncate" {
  run bash -c "echo '{\"foo\":\"bar\tbaz\"}' | $DAP_EXECUTABLE json + truncate foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":""}'
}

@test "insert" {
  run bash -c "echo '{\"foo\":\"bar\tbaz\"}' | $DAP_EXECUTABLE json + insert a=b + json | jq -Sc ."
  assert_success
  assert_output '{"a":"b","foo":"bar\tbaz"}'
}

@test "field_split_array" {
  run bash -c "echo '{\"foo\":[\"a\",2]}' | $DAP_EXECUTABLE json + field_split_array foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":["a",2],"foo.f1":"a","foo.f2":2}'
}

@test "exists" {
  run bash -c "echo '{\"foo\":\"bar\tbaz\"}' | $DAP_EXECUTABLE json + exists a + json | jq -Sc ."
  assert_success
  assert_output ''
  run bash -c "echo '{\"foo\":\"bar\tbaz\"}' | $DAP_EXECUTABLE json + exists foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":"bar\tbaz"}'
}

@test "split_line" {
  run bash -c "echo '{\"foo\":\"bar\nbaz\"}' | $DAP_EXECUTABLE json + split_line foo + json | jq -Sc ."
  assert_success
  assert_line --index 0 '{"foo":"bar\nbaz","foo.line":"bar"}'
  assert_line --index 1 '{"foo":"bar\nbaz","foo.line":"baz"}'
}

@test "select" {
  run bash -c "echo '{\"foo\":\"bar\", \"baz\":\"qux\", \"a\":\"b\"}' | $DAP_EXECUTABLE json + select foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":"bar"}'
  run bash -c "echo '{\"foo\":\"bar\", \"baz\":\"qux\", \"a\":\"b\"}' | $DAP_EXECUTABLE json + select foo baz + json | jq -Sc ."
  assert_success
  assert_output '{"baz":"qux","foo":"bar"}'
}

@test "remove" {
  run bash -c "echo '{\"foo\":\"bar\", \"baz\":\"qux\", \"a\":\"b\"}' | $DAP_EXECUTABLE json + remove foo baz + json | jq -Sc ."
  assert_success
  assert_output '{"a":"b"}'
}

@test "include" {
  run bash -c "echo '{\"foo\":\"bar\", \"baz\":\"qux\", \"a\":\"b\"}' | $DAP_EXECUTABLE json + include a=c + json | jq -Sc ."
  assert_success
  assert_output ''
  run bash -c "echo '{\"foo\":\"bar\", \"baz\":\"qux\", \"a\":\"b\"}' | $DAP_EXECUTABLE json + include a=b + json | jq -Sc ."
  assert_success
  assert_output '{"a":"b","baz":"qux","foo":"bar"}'
}

@test "transform" {
  run bash -c "echo '{\"foo\":\"bar\"}' | $DAP_EXECUTABLE json + transform foo=base64encode + json | jq -Sc ."
  assert_success
  assert_output '{"foo":"YmFy"}'
}

@test "recog_match" {
  run bash -c "echo '9.8.2rc1-RedHat-9.8.2-0.62.rc1.el6_9.2' | $DAP_EXECUTABLE lines + recog line=dns.versionbind + json | jq -Sc ."
  assert_success
  assert_output '{"line":"9.8.2rc1-RedHat-9.8.2-0.62.rc1.el6_9.2","line.recog.fingerprint_db":"dns.versionbind","line.recog.matched":"ISC BIND: Red Hat Enterprise Linux","line.recog.os.cpe23":"cpe:/o:redhat:enterprise_linux:6","line.recog.os.family":"Linux","line.recog.os.product":"Enterprise Linux","line.recog.os.vendor":"Red Hat","line.recog.os.version":"6","line.recog.os.version.version":"9","line.recog.service.cpe23":"cpe:/a:isc:bind:9.8.2rc1","line.recog.service.family":"BIND","line.recog.service.product":"BIND","line.recog.service.protocol":"dns","line.recog.service.vendor":"ISC","line.recog.service.version":"9.8.2rc1"}'
}

@test "recog_nomatch" {
  run bash -c "echo 'should not match' | $DAP_EXECUTABLE lines + recog line=dns.versionbind + json | jq -Sc ."
  assert_success
  assert_output '{"line":"should not match"}'
}

@test "recog_invalid_arg" {
  # currently fails in dap, passes in godap
  skip
  run bash -c "echo 'test' | $DAP_EXECUTABLE lines + recog + json"
  assert_failure
}

@test "geo_ip yields valid fields" {
  run bash -c "echo 66.92.181.240 | GEOIP_CITY_DATABASE_PATH=./test/test_data/geoip/GeoIPCity.dat $DAP_EXECUTABLE lines + geo_ip line + json | jq -Sc ."
  assert_success
  assert_output '{"line":"66.92.181.240","line.area_code":"510","line.city":"Fremont","line.country_code":"US","line.country_code3":"USA","line.country_name":"United States","line.dma_code":"807","line.latitude":"37.50790023803711","line.longitude":"-121.95999908447266","line.postal_code":"94538","line.region":"CA","line.region_name":"California"}'
}

@test "geo_ip_org yields valid fields" {
  run bash -c "echo 12.87.118.0 | GEOIP_ORG_DATABASE_PATH=./test/test_data/geoip/GeoIPOrg.dat $DAP_EXECUTABLE lines + geo_ip_org line + json | jq -Sc -r ."
  assert_success
  assert_output '{"line":"12.87.118.0","line.org":"AT&T Worldnet Services"}'
}

@test "geo_ip_asn" {
  run bash -c "echo 12.87.118.0 | GEOIP_ASN_DATABASE_PATH=./test/test_data/geoip/GeoIPASNum.dat $DAP_EXECUTABLE lines + geo_ip_asn line + json | jq -Sc -r ."
  assert_success
  assert_output '{"line":"12.87.118.0","line.asn":"AS7018"}'
}

@test "geo_ip2_city" {
  # test with default language
  run bash -c "echo 81.2.69.142 | GEOIP2_CITY_DATABASE_PATH=test/test_data/geoip2/GeoIP2-City-Test.mmdb $DAP_EXECUTABLE lines + geo_ip2_city line + json | jq -Sc -r ."
  assert_success
  assert_output '{"line":"81.2.69.142","line.geoip2.city.city.geoname_id":"2643743","line.geoip2.city.city.name":"London","line.geoip2.city.continent.code":"EU","line.geoip2.city.continent.geoname_id":"6255148","line.geoip2.city.continent.name":"Europe","line.geoip2.city.country.geoname_id":"2635167","line.geoip2.city.country.is_in_european_union":"true","line.geoip2.city.country.iso_code":"GB","line.geoip2.city.country.name":"United Kingdom","line.geoip2.city.location.accuracy_radius":"10","line.geoip2.city.location.latitude":"51.5142","line.geoip2.city.location.longitude":"-0.0931","line.geoip2.city.location.metro_code":"0","line.geoip2.city.location.time_zone":"Europe/London","line.geoip2.city.postal.code":"","line.geoip2.city.registered_country.geoname_id":"6252001","line.geoip2.city.registered_country.is_in_european_union":"false","line.geoip2.city.registered_country.iso_code":"US","line.geoip2.city.registered_country.name":"United States","line.geoip2.city.represented_country.geoname_id":"0","line.geoip2.city.represented_country.is_in_european_union":"false","line.geoip2.city.represented_country.iso_code":"","line.geoip2.city.represented_country.type":"","line.geoip2.city.subdivisions.0.geoname_id":"6269131","line.geoip2.city.subdivisions.0.iso_code":"ENG","line.geoip2.city.subdivisions.0.name":"England","line.geoip2.city.subdivisions.length":"1","line.geoip2.city.traits.is_anonymous_proxy":"false","line.geoip2.city.traits.is_satellite_provider":"false"}'

  # test with non-default language
  run bash -c "echo 67.43.156.0 | GEOIP2_CITY_DATABASE_PATH=test/test_data/geoip2/GeoIP2-City-Test.mmdb GEOIP2_LANGUAGE=fr $DAP_EXECUTABLE lines + geo_ip2_city line + json | jq -Sc -r ."
  assert_success
  assert_output '{"line":"67.43.156.0","line.geoip2.city.city.geoname_id":"0","line.geoip2.city.continent.code":"AS","line.geoip2.city.continent.geoname_id":"6255147","line.geoip2.city.continent.name":"Asie","line.geoip2.city.country.geoname_id":"1252634","line.geoip2.city.country.is_in_european_union":"false","line.geoip2.city.country.iso_code":"BT","line.geoip2.city.country.name":"Bhutan","line.geoip2.city.location.accuracy_radius":"534","line.geoip2.city.location.latitude":"27.5","line.geoip2.city.location.longitude":"90.5","line.geoip2.city.location.metro_code":"0","line.geoip2.city.location.time_zone":"Asia/Thimphu","line.geoip2.city.postal.code":"","line.geoip2.city.registered_country.geoname_id":"798549","line.geoip2.city.registered_country.is_in_european_union":"true","line.geoip2.city.registered_country.iso_code":"RO","line.geoip2.city.registered_country.name":"Roumanie","line.geoip2.city.represented_country.geoname_id":"0","line.geoip2.city.represented_country.is_in_european_union":"false","line.geoip2.city.represented_country.iso_code":"","line.geoip2.city.represented_country.type":"","line.geoip2.city.traits.is_anonymous_proxy":"true","line.geoip2.city.traits.is_satellite_provider":"false"}'

  # test IPv6
  run bash -c "echo 2a02:d9c0:: | GEOIP2_CITY_DATABASE_PATH=test/test_data/geoip2/GeoIP2-City-Test.mmdb $DAP_EXECUTABLE lines + geo_ip2_city line + json | jq -Sc -r ."
  assert_success
  assert_output '{"line":"2a02:d9c0::","line.geoip2.city.city.geoname_id":"0","line.geoip2.city.continent.code":"AS","line.geoip2.city.continent.geoname_id":"6255147","line.geoip2.city.continent.name":"Asia","line.geoip2.city.country.geoname_id":"298795","line.geoip2.city.country.is_in_european_union":"false","line.geoip2.city.country.iso_code":"TR","line.geoip2.city.country.name":"Turkey","line.geoip2.city.location.accuracy_radius":"100","line.geoip2.city.location.latitude":"39.05901","line.geoip2.city.location.longitude":"34.91155","line.geoip2.city.location.metro_code":"0","line.geoip2.city.location.time_zone":"Europe/Istanbul","line.geoip2.city.postal.code":"","line.geoip2.city.registered_country.geoname_id":"298795","line.geoip2.city.registered_country.is_in_european_union":"false","line.geoip2.city.registered_country.iso_code":"TR","line.geoip2.city.registered_country.name":"Turkey","line.geoip2.city.represented_country.geoname_id":"0","line.geoip2.city.represented_country.is_in_european_union":"false","line.geoip2.city.represented_country.iso_code":"","line.geoip2.city.represented_country.type":"","line.geoip2.city.traits.is_anonymous_proxy":"false","line.geoip2.city.traits.is_satellite_provider":"false"}'
}

@test "geo_ip2_asn" {
  run bash -c "echo 12.81.92.0 | GEOIP2_ASN_DATABASE_PATH=test/test_data/geoip2/GeoLite2-ASN-Test.mmdb $DAP_EXECUTABLE lines + geo_ip2_asn line + json | jq -Sc -r ."
  assert_success
  assert_output '{"line":"12.81.92.0","line.geoip2.asn.asn":"AS7018","line.geoip2.asn.asn_org":"AT&T Services"}'

  # test IPv6
  run bash -c "echo 2600:7000:: | GEOIP2_ASN_DATABASE_PATH=test/test_data/geoip2/GeoLite2-ASN-Test.mmdb $DAP_EXECUTABLE lines + geo_ip2_asn line + json | jq -Sc -r ."
  assert_success
  assert_output '{"line":"2600:7000::","line.geoip2.asn.asn":"AS6939","line.geoip2.asn.asn_org":"Hurricane Electric, Inc."}'
}

@test "geo_ip2_isp" {
  run bash -c "echo 12.81.92.0 | GEOIP2_ISP_DATABASE_PATH=test/test_data/geoip2/GeoIP2-ISP-Test.mmdb $DAP_EXECUTABLE lines + geo_ip2_isp line + json | jq -Sc -r ."
  assert_success
  assert_output '{"line":"12.81.92.0","line.geoip2.isp.asn":"AS7018","line.geoip2.isp.asn_org":"","line.geoip2.isp.isp":"AT&T Services","line.geoip2.isp.org":"AT&T Services"}'

  # test IPv6
  run bash -c "echo 2600:7000:: | GEOIP2_ISP_DATABASE_PATH=test/test_data/geoip2/GeoIP2-ISP-Test.mmdb $DAP_EXECUTABLE lines + geo_ip2_isp line + json | jq -Sc -r ."
  assert_success
  assert_output '{"line":"2600:7000::","line.geoip2.isp.asn":"AS6939","line.geoip2.isp.asn_org":"Hurricane Electric, Inc.","line.geoip2.isp.isp":"","line.geoip2.isp.org":""}'
}

@test "geo_ip2_legacy_compat" {
  run bash -c "echo 81.2.69.142 | GEOIP_CITY_DATABASE_PATH=./test/test_data/geoip/GeoIPCity.dat GEOIP2_CITY_DATABASE_PATH=test/test_data/geoip2/GeoIP2-City-Test.mmdb $DAP_EXECUTABLE lines + geo_ip2_city line + geo_ip2_legacy_compat line + match_remove line.geoip2 + json | jq -Sc -r ."
  assert_success
  assert_output '{"line":"81.2.69.142","line.city":"London","line.country.name":"United Kingdom","line.country_code":"GB","line.latitude":"51.5142","line.longitude":"-0.0931","line.postal_code":"","line.region":"ENG","line.region_name":"England"}'

  # test IPv6
  run bash -c "echo 2a02:d9c0:: | GEOIP_CITY_DATABASE_PATH=./test/test_data/geoip/GeoIPCity.dat GEOIP2_CITY_DATABASE_PATH=test/test_data/geoip2/GeoIP2-City-Test.mmdb $DAP_EXECUTABLE lines + geo_ip2_city  line + geo_ip2_legacy_compat line + match_remove line.geoip2 + json | jq -Sc -r ."
  assert_success
  assert_output '{"line":"2a02:d9c0::","line.country.name":"Turkey","line.country_code":"TR","line.latitude":"39.05901","line.longitude":"34.91155","line.postal_code":""}'
}
