SUMMARY = "Outillage d'analyse noyau et espace utilisateur pour Jetson"
DESCRIPTION = "Traceurs et profileurs noyau, outils de profilage C/C++, \
observation systeme. Les heatmaps se symbolisent sur l'hote a partir du \
rootfs de symboles produit par IMAGE_GEN_DEBUGFS."
LICENSE = "MIT"

PV = "1.1"

inherit packagegroup

# lttng-modules depend du noyau de la machine.
PACKAGE_ARCH = "${MACHINE_ARCH}"

PACKAGES = "${PN} ${PN}-kernel ${PN}-userspace ${PN}-observe"

RDEPENDS:${PN} = "${PN}-kernel ${PN}-userspace ${PN}-observe"

# libbpf n'est pas nomme : la politique de nommage le renomme en
# libbpf1, et bpftool, bcc et bpftrace le tirent deja par leurs
# dependances de bibliotheques partagees.
RDEPENDS:${PN}-kernel = " \
    perf \
    trace-cmd \
    bpftrace \
    bpftool \
    bcc \
    systemtap \
    lttng-tools \
    lttng-modules \
    blktrace \
    crash \
    kexec-tools \
    makedumpfile \
    pahole \
"

RDEPENDS:${PN}-userspace = " \
    gdb \
    gdbserver \
    valgrind \
    ltrace \
    strace \
    uftrace \
    heaptrack \
    lttng-ust \
    gperftools \
    elfutils \
"

RDEPENDS:${PN}-observe = " \
    sysstat \
    htop \
    atop \
    iotop \
    lsof \
    procps \
    psmisc \
    stress-ng \
    fio \
    rt-tests \
"
