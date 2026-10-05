# SPDX-License-Identifier: MIT
#
# capture-access - installe une cle publique SSH pour root, pour les
# captures automatisees (bin/jetson-capture.sh).
#
# Inactive par defaut : une configuration de build l'ajoute a
# IMAGE_CLASSES et pose CAPTURE_SSH_PUBKEY. Les images de production ne
# l'activent pas.

CAPTURE_SSH_PUBKEY ??= ""

ROOTFS_POSTPROCESS_COMMAND:append = " capture_access_install_key"

capture_access_install_key() {
    if [ -z "${CAPTURE_SSH_PUBKEY}" ] || [ ! -f "${CAPTURE_SSH_PUBKEY}" ]; then
        bbfatal "capture-access : CAPTURE_SSH_PUBKEY absent ou illisible (${CAPTURE_SSH_PUBKEY})"
    fi
    install -d -m 0700 ${IMAGE_ROOTFS}${ROOT_HOME}/.ssh
    install -m 0600 ${CAPTURE_SSH_PUBKEY} ${IMAGE_ROOTFS}${ROOT_HOME}/.ssh/authorized_keys
}
