# DAP: The Data Analysis Pipeline

[![Gem Version](https://badge.fury.io/rb/dap.svg)](http://badge.fury.io/rb/dap)

DAP was created to transform text-based data on the command-line, specializing in transforms that are annoying or difficult to do with existing tools.

DAP reads data using an input plugin, transforms it through a series of filters, and prints it out again using an output plugin. Every record is treated as a document (aka: hash/dict) and filters are used to reduce, expand, and transform these documents as they pass through. Think of DAP as a mashup between sed, awk, grep, csvtool, and jq, with map/reduce capabilities.

DAP was written to process terabyte-sized public scan datasets, such as those provided by https://scans.io/. Although DAP isn't particularly fast, it can be used across multiple cores (and machines) by splitting the input source and wrapping the execution with GNU Parallel.

## Installation

### Prerequisites

DAP requires Ruby and is best suited for systems with a relatively current version with 2.6.x being the minimum requirement.
Ideally, this will be managed with either
[`rbenv`](https://github.com/rbenv/rbenv) or [`rvm`](https://rvm.io/) with the bundler gem also installed and up to date.
Using system managed/installed Rubies is possible but fraught with peril.

#### Maxmind IP Location Databases

If you intend on using any of the `geo_ip*` or `geo_ip2*` filters, you must
install the databases that provide the data for these filters.  If you do not
intend on using these filters, you can skip this step.

`dap` versions 1.4.x and later depend on [Maxmind's geoip2/geolite2
databases](https://dev.maxmind.com/geoip/geoip2/geolite2/) to be able to append
geographic and related metadata to analyzed datasets.  In order to use this
functionality you must put your copy of the relevant Maxmind databases in the
correct location in `/var/lib/geoip2` or the `data` directory of your `dap`
installation or override with an environment variable that specifies the full
path to the database in question:

* ASN: `GeoLite2-ASN.mmdb` (environment override: `GEOIP2_ASN_DATABASE_PATH`)
* City: `GeoLite2-City.mmdb` (environment override: `GEOIP2_CITY_DATABASE_PATH`)
* ISP: `GeoIP2-ISP.mmdb` (environment override: `GEOIP2_ISP_DATABASE_PATH`)

*NOTE*: Prior to `dap` version 1.4.x there was a dependency on [Maxmind's geoip
database](http://dev.maxmind.com/geoip/legacy/downloadable/)
to be able to append geographic metadata to analyzed datasets.  However, since
that time Maxmind has dropped support for these legacy databases.  If you
intend to continue using this deprecated functionality, you must put your copy
of the relevant Maxmind legacy databases in the correct location in
`/var/lib/geoip` or the `data` directory of your `dap` installation or override
with an environment variable that specifies the full path to the database in question:

* ASN: `GeoIPASNum.dat` (environment override in 1.4.x+: `GEOIP_ASN_DATABASE_PATH`)
* City: `geoip_city.dat` (environment override in 1.4.x+: `GEOIP_CITY_DATABASE_PATH`)
* Org: `geoip_org.dat` (environment override in 1.4.x+: `GEOIP_ORG_DATABASE_PATH`)

### Ubuntu 16.04+

```bash
sudo apt-get install zlib1g-dev ruby ruby-dev gcc make ruby-bundler
gem install dap
```

### OS X

```bash
# Install the GeoIP C library required by DAP
brew update
brew install geoip

gem install dap
```

## Usage

In its simplest form, DAP takes input, applies zero or more filters which modify the input, and then outputs the result.  The input, filters and output are separated by plus signs (`+`).  As seen from `dap -h`:

```shell
Usage: dap  [input] + [filter] + [output]
       --inputs
       --outputs
       --filters
```

To see which input/output formats are supported and what filters are available, run `dap --inputs`,`dap --outputs` or `dap --filters`, respectively.

This example reads as input a single IP address from `STDIN` in line form, applies geo-ip transformations as a filter on that line, and then returns the output as JSON:

```shell
$   echo 8.8.8.8 | bin/dap + lines + geo_ip2_city line + json | jq .
{
  "line": "8.8.8.8",
  "line.geoip2.city.city.geoname_id": "0",
  "line.geoip2.city.continent.code": "NA",
  "line.geoip2.city.continent.geoname_id": "6255149",
  "line.geoip2.city.country.geoname_id": "6252001",
  "line.geoip2.city.country.iso_code": "US",
  "line.geoip2.city.country.is_in_european_union": "false",
  "line.geoip2.city.location.accuracy_radius": "1000",
  "line.geoip2.city.location.latitude": "37.751",
  "line.geoip2.city.location.longitude": "-97.822",
  "line.geoip2.city.location.metro_code": "0",
  "line.geoip2.city.location.time_zone": "America/Chicago",
  "line.geoip2.city.postal.code": "",
  "line.geoip2.city.registered_country.geoname_id": "6252001",
  "line.geoip2.city.registered_country.iso_code": "US",
  "line.geoip2.city.registered_country.is_in_european_union": "false",
  "line.geoip2.city.represented_country.geoname_id": "0",
  "line.geoip2.city.represented_country.iso_code": "",
  "line.geoip2.city.represented_country.is_in_european_union": "false",
  "line.geoip2.city.represented_country.type": "",
  "line.geoip2.city.traits.is_anonymous_proxy": "false",
  "line.geoip2.city.traits.is_satellite_provider": "false",
  "line.geoip2.city.continent.name": "North America",
  "line.geoip2.city.country.name": "United States",
  "line.geoip2.city.registered_country.name": "United States"
}
```

There are also several examples of how to use DAP along with sample datasets [here](samples).
