SUMMARY = "Image custom minimale avec nos outils"
LICENSE = "MIT"

# Nécessaire pour que 'runqemu qemux86-64 custom-image' fonctionne
IMAGE_LINK_NAME = "custom-image-${MACHINE}"

# packagegroup-core-boot = kernel + init + busybox (le minimum pour booter)
# ${CORE_IMAGE_EXTRA_INSTALL} = hook pour ajouter des paquets depuis local.conf
# hello-custom = notre recette custom
IMAGE_INSTALL = "packagegroup-core-boot ${CORE_IMAGE_EXTRA_INSTALL} hello-custom packagegroup-selinux-minimal"

IMAGE_LINGUAS = " "

inherit core-image

# Taille max du rootfs en KB (50MB)
IMAGE_ROOTFS_SIZE ?= "51200"
IMAGE_ROOTFS_EXTRA_SPACE:append = "${@bb.utils.contains("DISTRO_FEATURES", "systemd", " + 4096", "", d)}"

# Hardening D2 : pas de debug-tweaks
IMAGE_FEATURES:remove = "debug-tweaks"
IMAGE_FEATURES += "read-only-rootfs"

# Mot de passe root obligatoire sans debug-tweaks
# Credentials séparés — ne pas versionner credentials.inc
require credentials.inc
