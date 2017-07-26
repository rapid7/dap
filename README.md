# DAP: The Data Analysis Pipeline

[![Gem Version](https://badge.fury.io/rb/dap.svg)](http://badge.fury.io/rb/dap)
[![Build Status](https://travis-ci.org/rapid7/dap.svg?branch=master)](https://travis-ci.org/rapid7/dap)

DAP was created to transform text-based data on the command-line, specializing in transforms that are annoying or difficult to do with existing tools.

DAP reads data using an input plugin, transforms it through a series of filters, and prints it out again using an output plugin. Every record is treated as a document (aka: hash/dict) and filters are used to reduce, expand, and transform these documents as they pass through. Think of DAP as a mashup between sed, awk, grep, csvtool, and jq, with map/reduce capabilities.

DAP was written to process terabyte-sized public scan datasets, such as those provided by https://scans.io/. Although DAP isn't particularly fast, it can be used across multiple cores (and machines) by splitting the input source and wrapping the execution with GNU Parallel.


## Installation

### Prerequisites

DAP requires Ruby, and is best suited for systems with a relatively current version,
preferably one installed and managed by
[`rbenv`](https://github.com/rbenv/rbenv) or [`rvm`](https://rvm.io/).  Using
system managed/installed Rubies is possible but fraught with peril.

DAP depends on [Maxmind's geoip database](http://dev.maxmind.com/geoip/legacy/downloadable/) to be able to append geographic metadata to analyzed datasets.  If you intend on using this capability, run the following as `root`:

```bash
mkdir -p /var/lib/geoip && cd /var/lib/geoip && wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz && gunzip GeoLiteCity.dat.gz && mv GeoLiteCity.dat geoip.dat && wget http://geolite.maxmind.com/download/geoip/database/GeoIPASNum.dat.gz && gunzip GeoIPASNum.dat.gz

```

### Ubuntu

```bash
sudo apt-get install libgeoip-dev
gem install dap
```

### OS X

```bash
brew update
brew install geoip
gem install dap
```

## Usage

In its simplest form, DAP takes input, applies zero or more filters which modify the input, and then outputs the result.  The input, filters and output are separated by plus signs (`+`).  As seen from `dap -h`:

```
Uage: dap  [input] + [filter] + [output]
       --inputs
       --outputs
       --filters
```

To see which input/output formats are supported and what filters are available, run `dap --inputs`,`dap --outputs` or `dap --filters`, respectively.

This example reads as input a single IP address from `STDIN` in line form, applies geo-ip transofmrations as a filter on that line, and then returns the output as JSON:

```
$  echo 8.8.8.8 | bin/dap + lines + geo_ip line + json
{"line":"8.8.8.8","line.country_code":"US","line.country_code3":"USA","line.country_name":"United States","line.latitude":"38.0","line.longitude":"-97.0"}
```

This example does the same, but only outputs the geo-ip country code:

```
$  echo 8.8.8.8 | bin/dap + lines + geo_ip line + select line.country_code3 + lines
USA
```

There are also several examples of how to use DAP along with sample datasets [here](samples).
