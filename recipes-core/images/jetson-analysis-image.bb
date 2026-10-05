SUMMARY = "Image d'analyse profonde noyau et OS pour Jetson"
DESCRIPTION = "Image yocto-jetson-tegra-hardened portant l'outillage \
d'analyse : traceurs noyau, profileurs C/C++, observation. Le rootfs de \
symboles (IMAGE_GEN_DEBUGFS) sert a symboliser perf, heaptrack et \
uftrace sur l'hote."
LICENSE = "MIT"

inherit core-image

IMAGE_INSTALL = " \
    packagegroup-core-boot \
    packagegroup-selinux-minimal \
    packagegroup-jetson-analysis \
    analysis-demo \
    analysis-demo-dbg \
    rsync \
    ${CORE_IMAGE_EXTRA_INSTALL} \
"

IMAGE_LINGUAS = " "

IMAGE_FEATURES += "ssh-server-openssh"

# Rootfs en lecture-ecriture : perf, heaptrack et uftrace ecrivent leurs
# traces sur la cible.
IMAGE_FEATURES:remove = "read-only-rootfs"

# Symboles a part, pour l'hote (perf report --symfs, heaptrack_print).
IMAGE_GEN_DEBUGFS = "1"
IMAGE_FSTYPES_DEBUGFS = "tar.zst"

# Marge pour les traces capturees sur la cible (Ko).
IMAGE_ROOTFS_EXTRA_SPACE = "2097152"

require credentials.inc
