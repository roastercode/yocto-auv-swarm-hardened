DESCRIPTION = "Hello World depuis notre layer custom"
SECTION = "examples"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Source locale — BitBake cherche dans le sous-dossier files/ de la recette
SRC_URI = "file://hello-custom.c"

# Le .c est copié directement dans UNPACKDIR (pas d'archive à extraire)
S = "${UNPACKDIR}"

do_compile() {
    # Tous les avertissements, traites en erreurs.
    ${CC} ${CFLAGS} ${LDFLAGS} \
        -Wall -Wextra -Wformat=2 -Werror=format -Wshadow \
        -Wmissing-prototypes -Wmissing-declarations -Wundef \
        -Wstrict-prototypes -Wconversion -Wsign-conversion \
        -Wcast-qual -Wpointer-arith -D_FORTIFY_SOURCE=2 \
        -fstack-protector-strong -fanalyzer -Werror \
        hello-custom.c -o hello-custom
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 hello-custom ${D}${bindir}
}
