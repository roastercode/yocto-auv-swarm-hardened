# rmw_zenoh_cpp loads rosidl_typesupport_fastrtps_c and _cpp, whose CMake
# extras call find_package(rosidl_generator_c) and (rosidl_generator_cpp)
# at configure time, and the dependencies they export in turn (such as
# fastrtps_cmake_module). The generated recipe does not depend on them, so
# configure fails with "Could not find a package configuration file
# provided by rosidl_generator_c".
#
# Tied to 0.2.10 on purpose: a version bump leaves this append dangling,
# and bitbake reports it.

DEPENDS += "rosidl-generator-c rosidl-generator-cpp fastrtps-cmake-module"

# The generated recipe copies "BSD" from package.xml, which is not an
# SPDX identifier: do_populate_lic and do_create_spdx find no license
# text. BSD-2-Clause is what the license headers of these sources say.
LICENSE = "Apache-2.0 & BSD-2-Clause"
