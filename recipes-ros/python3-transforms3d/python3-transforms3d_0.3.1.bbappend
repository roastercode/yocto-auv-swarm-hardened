# transforms3d 0.3.1 ships an old versioneer.py that calls
# configparser.SafeConfigParser and parser.readfp, both removed in
# Python 3.12. Use their replacements, ConfigParser and read_file.
#
# Pulled by tf-transformations, which nmea_navsat_driver needs.
# Tied to 0.3.1 on purpose: a version bump leaves this append dangling,
# and bitbake reports it.

do_configure:prepend() {
    sed -i -e 's/configparser\.SafeConfigParser()/configparser.ConfigParser()/' \
           -e 's/parser\.readfp(/parser.read_file(/' \
           ${S}/versioneer.py
}
