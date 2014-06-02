# DAP: The Data Analysis Pipeline

DAP was created to transform text-based data on the command-line, specializing in transforms that are annoying or difficult to do with existing tools.

DAP reads data using an input plugin, transforms it through a series of filters, and prints it out again using an output plugin. Every record is treated as a document (aka: hash/dict) and filters are used to reduce, expand, and transform these documents as they pass through. Think of DAP as a mashup between sed, awk, grep, csvtool, and jq, with map/reduce capabilities.

DAP was written to process terabyte-sized public scan datasets, such as those provided by https://scans.io/. Although DAP isn't particularly fast, it can be used across multiple cores (and machines) by splitting the input source and wrapping the execution with GNU Parallel.

## Prerequisites

DAP depends on GeoIP (http://dev.maxmind.com/geoip/legacy/downloadable/) to be able to append geographic metadata to analyzed datasets.  At least on Ubuntu, the libgeoip-dev package provides this capability.

## Usage

See [tree/master/samples](/tree/master/samples)
