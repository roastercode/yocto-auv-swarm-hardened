# The generated recipe copies the license from package.xml as "BSD",
# which is not an SPDX identifier: do_create_spdx finds no license text
# and fails. meta-ros sets BSD-3-Clause for this same package in its
# kilted, rolling, lyrical and spaceros-jazzy layers; jazzy lacks it.
#
# Tied to 1.0.6-2 on purpose: a version bump leaves this append
# dangling, and bitbake reports it.

LICENSE = "BSD-3-Clause"
