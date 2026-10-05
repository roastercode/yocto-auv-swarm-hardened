SUMMARY = "Charge C++ de demonstration pour perf, flame graphs et heatmaps"
DESCRIPTION = "Quatre phases successives (matrices, tri, table de hachage, \
expressions regulieres), chacune dans sa propre fonction, pour que les \
piles et la heatmap se lisent sans legende."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://analysis-demo.cpp"
S = "${UNPACKDIR}"

# Tous les avertissements, traites en erreurs. -Wmissing-prototypes et
# -Wstrict-prototypes sont propres au C ; -fanalyzer reste incomplet en
# C++ et produit des faux positifs dans libstdc++.
# Pointeurs de cadre et -g : perf -g remonte les piles sans DWARF, et le
# paquet -dbg donne les noms et les lignes.
DEMO_WARNINGS = "-Wall -Wextra -Wformat=2 -Werror=format -Wshadow \
    -Wmissing-declarations -Wundef -Wconversion -Wsign-conversion \
    -Wcast-qual -Wpointer-arith -Werror"

do_compile() {
    ${CXX} ${CXXFLAGS} ${LDFLAGS} -std=c++17 -g -fno-omit-frame-pointer \
        ${DEMO_WARNINGS} -D_FORTIFY_SOURCE=2 -fstack-protector-strong \
        analysis-demo.cpp -o analysis-demo
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 analysis-demo ${D}${bindir}
}
