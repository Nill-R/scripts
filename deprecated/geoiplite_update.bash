#!/usr/bin/env bash

LICENSE_KEY=YOUR_LICENSE_KEY_HERE
GEOIP_DIR=YOUR_GEOIP_DIR_HERE

cd $(mktemp -d /tmp/GeoIP.XXXXXXX)
TEMP_DIR=$(pwd)
mkdir -p $GEOIP_DIR

curl "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=$LICENSE_KEY&suffix=tar.gz" -o GeoLite-Country.tar.gz
curl "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=$LICENSE_KEY&suffix=tar.gz" -o GeoLite2-City.tar.gz
curl "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-ASN&license_key=$LICENSE_KEY&suffix=tar.gz" -o GeoLite-ASN.tar.gz

tar xzf GeoLite2-City.tar.gz
tar xzf GeoLite-ASN.tar.gz
tar xzf GeoLite-Country.tar.gz

mv $GEOIP_DIR/country.mmdb $GEOIP_DIR/country.mmdb.old
mv $GEOIP_DIR/city.mmdb $GEOIP_DIR/city.mmdb.old
mv $GEOIP_DIR/asn.mmdb $GEOIP_DIR/asn.mmdb.old
mv GeoLite2-Country_*/GeoLite2-Country.mmdb $GEOIP_DIR/country.mmdb
mv GeoLite2-City_*/GeoLite2-City.mmdb $GEOIP_DIR/city.mmdb
mv GeoLite2-ASN_*/GeoLite2-ASN.mmdb $GEOIP_DIR/asn.mmdb

cd /tmp

rm -rf "$TEMP_DIR"
exit 0
