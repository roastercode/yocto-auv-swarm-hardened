# Tied to 2.1.0-3 on purpose: a version bump leaves this append dangling,
# and bitbake reports it.

# The generated recipe copies "BSD" from package.xml, which is not an
# SPDX identifier: do_populate_lic and do_create_spdx find no license
# text. The release sources carry no license header or file;
# BSD-3-Clause is what the upstream LICENSE.txt (ros-drivers/nmea_msgs,
# branch master) says.
LICENSE = "BSD-3-Clause"
