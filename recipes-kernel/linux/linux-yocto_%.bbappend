# Activation dm-verity via fragment de config kernel
FILESEXTRAPATHS:prepend := "${THISDIR}:"

SRC_URI:append = " file://dm-verity.cfg"

# --- Outillage d'analyse (yocto-jetson-tegra-hardened) ---
#
# Toujours : BTF (bpftrace, bcc, bpftool), ftrace/kprobes/uprobes,
# observation (PSI, delay accounting, blktrace), PMU ARM (PMUv3, SPE,
# CoreSight ETM), detecteur de taches bloquees.
#
# ANALYSIS_PROFILE choisit l'instrumentation des verrous :
#   measure  verrous non instrumentes : durees et heatmaps mesurent le
#            code, pas lockdep (defaut)
#   debug    lockdep, PROVE_LOCKING, kmemleak, DEBUG_OBJECTS
#
# ANALYSIS_KASAN / ANALYSIS_KCSAN : investigation seulement, l'un ou
# l'autre, jamais les deux, jamais pour une mesure.
ANALYSIS_PROFILE ??= "measure"
ANALYSIS_KASAN ??= "0"
ANALYSIS_KCSAN ??= "0"

# BTF demande pahole a la configuration et a l'edition de liens.
# linux-yocto.inc passe PAHOLE=false et n'installe pas pahole avant
# do_kernel_configme tant que KERNEL_DEBUG ne vaut pas "True" : le
# Kconfig voit alors PAHOLE_VERSION=0 et retire DEBUG_INFO_BTF sans le
# dire. KERNEL_DEBUG ajoute aussi debug-btf.scc et reproducibility.scc.
KERNEL_DEBUG = "True"

SRC_URI:append = " \
    file://analysis/btf.cfg \
    file://analysis/trace.cfg \
    file://analysis/observe.cfg \
    file://analysis/arm64-pmu.cfg \
    file://analysis/hung-task.cfg \
    ${@oe.utils.conditional('ANALYSIS_PROFILE', 'debug', 'file://analysis/lockdep.cfg file://analysis/sanity.cfg', 'file://analysis/nodebug.cfg', d)} \
    ${@oe.utils.conditional('ANALYSIS_KASAN', '1', 'file://analysis/kasan.cfg', '', d)} \
    ${@oe.utils.conditional('ANALYSIS_KCSAN', '1', 'file://analysis/kcsan.cfg', '', d)} \
"

python () {
    if d.getVar('ANALYSIS_KASAN') == '1' and d.getVar('ANALYSIS_KCSAN') == '1':
        bb.fatal("ANALYSIS_KASAN et ANALYSIS_KCSAN : chacun instrumente tous les acces memoire, ils ne partagent pas un noyau")
    if d.getVar('ANALYSIS_PROFILE') not in ('measure', 'debug'):
        bb.fatal("ANALYSIS_PROFILE doit valoir measure ou debug")
}

# KASAN inscrit le chemin source dans chaque objet ; le controle
# buildpaths refuse alors tous les modules.
ERROR_QA:remove = "${@oe.utils.conditional('ANALYSIS_KASAN', '1', 'buildpaths', '', d)}"
WARN_QA:remove = "${@oe.utils.conditional('ANALYSIS_KASAN', '1', 'buildpaths', '', d)}"

# Les fragments de cette couche doivent se retrouver tels quels dans le
# .config final. L'audit de kernel-yocto ne les signale pas au niveau 1
# (--classify ne retient que les options critiques au boot) et, au niveau
# 2, les noie dans les ecarts du BSP. On verifie donc les notres, et un
# ecart arrete le build.
ANALYSIS_FRAGMENT_DIR := "${THISDIR}"

python do_kernel_configcheck:append() {
    # Pas d'import ici : le corps est colle a la fonction d'origine, et un
    # import os rendrait os local a toute la fonction (UnboundLocalError
    # dans la partie d'origine). os est deja fourni par bitbake.
    fragdir = d.getVar('ANALYSIS_FRAGMENT_DIR')
    dotconfig = {}
    with open(os.path.join(d.getVar('B'), '.config')) as f:
        for line in f:
            line = line.rstrip('\n')
            if line.startswith('CONFIG_') and '=' in line:
                k, v = line.split('=', 1)
                dotconfig[k] = v
            elif line.startswith('# CONFIG_') and line.endswith(' is not set'):
                dotconfig[line[2:-11]] = 'n'
    errors = []
    checked = 0
    for uri in (d.getVar('SRC_URI') or '').split():
        if not uri.startswith('file://') or not uri.endswith('.cfg'):
            continue
        rel = uri[len('file://'):]
        path = os.path.join(fragdir, rel)
        if not os.path.isfile(path):
            continue
        with open(path) as f:
            for n, line in enumerate(f, 1):
                line = line.strip()
                if line.startswith('CONFIG_') and '=' in line:
                    k, want = line.split('=', 1)
                elif line.startswith('# CONFIG_') and line.endswith(' is not set'):
                    k, want = line[2:-11], 'n'
                else:
                    continue
                checked += 1
                got = dotconfig.get(k, 'n')
                if got != want:
                    errors.append('%s:%d %s voulu %s, .config %s' % (rel, n, k, want, got))
    if errors:
        bb.fatal('fragments de la couche non appliques :\n  ' + '\n  '.join(errors))
    bb.note('fragments de la couche : %d options verifiees, toutes appliquees' % checked)
}
