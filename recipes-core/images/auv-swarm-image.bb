SUMMARY = "AUV swarm node image"
DESCRIPTION = "Hardened image for an AUV swarm node: ROS 2 Jazzy over \
Zenoh, navigation, timing and fieldbus tools, plus the base layer's \
analysis tooling for development."
LICENSE = "MIT"

inherit core-image
inherit ros_distro_${ROS_DISTRO}
inherit ${ROS_DISTRO_TYPE}_image

IMAGE_INSTALL = " \
    packagegroup-core-boot \
    packagegroup-selinux-minimal \
    packagegroup-auv-swarm \
    packagegroup-jetson-analysis \
    rsync \
    ${CORE_IMAGE_EXTRA_INSTALL} \
"

IMAGE_LINGUAS = " "

IMAGE_FEATURES += "ssh-server-openssh"

# Development image: traces and logs are written on the target.
IMAGE_FEATURES:remove = "read-only-rootfs"

IMAGE_GEN_DEBUGFS = "1"
IMAGE_FSTYPES_DEBUGFS = "tar.zst"
IMAGE_ROOTFS_EXTRA_SPACE = "2097152"

require credentials.inc
