# zenoh-cpp-vendor 0.2.10 has a USE_SYSTEM_ZENOH option upstream. The
# meta-ros patch doing the same was written for 0.2.9 and no longer
# applies: drop it and use the option. zenoh-c and zenoh-cpp come from
# meta-zenoh (meta-ros adds them to the build dependencies).
#
# This append is tied to 0.2.10 on purpose: a version bump in meta-ros
# leaves it dangling, and bitbake reports it.

SRC_URI:remove = "file://use-system-zenoh.patch"

EXTRA_OECMAKE:append = " -DUSE_SYSTEM_ZENOH=ON"
