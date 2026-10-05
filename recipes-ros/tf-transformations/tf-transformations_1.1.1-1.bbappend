# Tied to 1.1.1-1 on purpose: a version bump leaves this append dangling,
# and bitbake reports it.

# The generated recipe copies "BSD" from package.xml, which is not an
# SPDX identifier: do_populate_lic and do_create_spdx find no license
# text. BSD-3-Clause is what the license headers of these sources say.
LICENSE = "BSD-3-Clause"
