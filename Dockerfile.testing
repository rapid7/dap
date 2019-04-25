FROM ubuntu:18.04

ENV TEST_DIR /opt/bats_testing
RUN apt-get update
RUN apt-get install -y build-essential ca-certificates curl git jq libffi-dev libgeoip-dev libxml2-dev wget zlib1g-dev

# install rvm and necessary ruby bits
RUN curl -sSL https://rvm.io/mpapis.asc | gpg --import -
RUN curl -sSL https://rvm.io/pkuczynski.asc | gpg --import -
RUN curl -sSL https://get.rvm.io | bash -s stable
RUN /bin/bash -l -c "rvm requirements"
RUN /bin/bash -l -c "rvm install 2.4.5"
RUN /bin/bash -l -c "rvm use 2.4.5 && gem update --system && gem install bundler"
ADD Gemfile* $TEST_DIR/
RUN /bin/bash -l -c "cd $TEST_DIR && rvm use 2.4.5 && bundle install"

# install maxmind legacy data
RUN mkdir /var/lib/geoip
COPY test/test_data/geoip/*.dat /var/lib/geoip/
# Note that these test files were copied from
# https://github.com/maxmind/geoip-api-php/raw/master/tests/data/GeoIPCity.dat
# https://github.com/maxmind/geoip-api-php/raw/master/tests/data/GeoIPASNum.dat
# https://github.com/maxmind/geoip-api-php/raw/master/tests/data/GeoIPOrg.dat

# install maxmind geoip2 data
RUN mkdir /var/lib/geoip2
COPY test/test_data/geoip2/*.mmdb /var/lib/geoip2/
# Note that these test files were copied from
# https://github.com/maxmind/MaxMind-DB/raw/f6ed981c23b0eb33d7c07568e2177236252afda6/test-data/GeoLite2-ASN-Test.mmdb
# https://github.com/maxmind/MaxMind-DB/raw/f6ed981c23b0eb33d7c07568e2177236252afda6/test-data/GeoIP2-City-Test.mmdb
# https://github.com/maxmind/MaxMind-DB/blob/f6ed981c23b0eb33d7c07568e2177236252afda6/test-data/GeoIP2-ISP-Test.mmdb

# install bats
RUN git clone https://github.com/sstephenson/bats.git && cd bats && ./install.sh /usr

WORKDIR /opt/bats_testing
COPY . .
