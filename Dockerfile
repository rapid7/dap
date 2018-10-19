FROM ubuntu:latest

RUN apt-get update
RUN apt-get install -y \
  ca-certificates \
  ruby \
  ruby-dev \
  git \
  make \
  g++ \
  libffi-dev \
  libgeoip-dev

RUN apt-get install -y libxml2-dev zlib1g-dev

RUN gem install bundler

RUN apt-get install -y wget && mkdir -p /var/lib/geoip && cd /var/lib/geoip && wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz && gunzip GeoLiteCity.dat.gz && mv GeoLiteCity.dat geoip.dat

RUN gem install dap -s https://github.com/rapid7/dap

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENTRYPOINT ["dap"]
