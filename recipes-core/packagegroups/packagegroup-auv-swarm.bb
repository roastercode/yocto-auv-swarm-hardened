SUMMARY = "AUV swarm node: middleware, navigation, timing, fieldbus"
DESCRIPTION = "ROS 2 Jazzy over Zenoh, GNSS and state estimation, \
time synchronization, SocketCAN tools."
LICENSE = "MIT"

PV = "1.0"

inherit packagegroup

PACKAGES = "${PN} ${PN}-middleware ${PN}-navigation ${PN}-timing ${PN}-fieldbus"

RDEPENDS:${PN} = "${PN}-middleware ${PN}-navigation ${PN}-timing ${PN}-fieldbus"

# ros-core rather than ros-base: ros-base pulls geometry2, hence
# tf2_bullet and the bullet physics engine, which needs OpenGL
# and X11. An AUV needs transforms, not a collision engine.
RDEPENDS:${PN}-middleware = " \
    ros-core \
    tf2-ros \
    tf2-geometry-msgs \
    rmw-zenoh-cpp \
    zenoh \
    auv-ros-env \
"

RDEPENDS:${PN}-navigation = " \
    gpsd \
    gps-utils \
    robot-localization \
    nmea-navsat-driver \
"

RDEPENDS:${PN}-timing = " \
    chrony \
    chronyc \
    linuxptp \
    pps-tools \
"

RDEPENDS:${PN}-fieldbus = " \
    can-utils \
    iproute2 \
"
