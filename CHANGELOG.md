# Changelog

## 0.2.0

- Fork of yocto-jetson-tegra-hardened, full history merged.
- Layer renamed to auv-swarm-hardened; it replaces the base in bblayers.conf.
- Distribution poky-auv-hardened.
- Kernel: PREEMPT_RT (AUV_PREEMPT_RT), SocketCAN, PPS and PTP, USB serial,
  each fragment checked against the final .config.
- packagegroup-auv-swarm: ROS 2 Jazzy, rmw_zenoh, zenohd, gpsd,
  robot_localization, chrony, linuxptp, can-utils.
- Image auv-swarm-image.
- rmw_zenoh uses meta-zenoh's zenoh-c and zenoh-cpp through the upstream
  USE_SYSTEM_ZENOH option; Zenoh pinned to 1.8.0.
- meta-ros and meta-zenoh pinned in conf/layers.pin.
- python3-transforms3d 0.3.1: versioneer fixed for Python 3.12
  (needed by nmea_navsat_driver through tf-transformations).
- jetson-follow.py 0.2.0: --pid stops the live view when the build ends,
  exit status from the bitbake logs.
- rmw-zenoh-cpp 0.2.10: missing build dependencies added (rosidl_generator_c,
  rosidl_generator_cpp and what the fastrtps typesupports export).
- geographic-msgs 1.0.6-2: LICENSE set to BSD-3-Clause, as meta-ros does for
  its other ROS distributions ("BSD" is not an SPDX identifier).
- nmea-msgs, nmea-navsat-driver, rmw-zenoh-cpp, tf-transformations: generic
  "BSD" license replaced by the exact BSD variant their sources or upstream
  LICENSE file carry.

## 0.1.1

- README and CHANGELOG translated to English.

## 0.1.0

- Repository created: README describing the architecture, operating configurations
  (EMCON), communications, navigation, OS foundation and open work items.
