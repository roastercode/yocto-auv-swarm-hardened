SUMMARY = "ROS 2 middleware selection for the AUV swarm"
DESCRIPTION = "Sets RMW_IMPLEMENTATION for login shells from the \
distribution's AUV_RMW_IMPLEMENTATION."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://auv-ros.sh.in"
S = "${UNPACKDIR}"

inherit allarch

AUV_RMW_IMPLEMENTATION ??= "rmw_zenoh_cpp"

do_install() {
    install -d ${D}${sysconfdir}/profile.d
    sed 's/@RMW@/${AUV_RMW_IMPLEMENTATION}/' ${S}/auv-ros.sh.in \
        > ${D}${sysconfdir}/profile.d/auv-ros.sh
    chmod 0644 ${D}${sysconfdir}/profile.d/auv-ros.sh
}

FILES:${PN} = "${sysconfdir}/profile.d/auv-ros.sh"
