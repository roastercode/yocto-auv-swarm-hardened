# AUV swarm kernel configuration, on top of the base layer's.
#
#   rt.cfg          PREEMPT_RT (AUV_PREEMPT_RT, default on)
#   can.cfg         SocketCAN core and USB CAN adapters (thrusters, ESCs)
#   timing.cfg      PPS and PTP (GNSS time, clock synchronization)
#   usb-serial.cfg  USB serial adapters (acoustic and optical modems, GNSS)
#
# AUV_PREEMPT_RT = "0" in local.conf builds without PREEMPT_RT, for
# when an out-of-tree driver does not support it.

FILESEXTRAPATHS:prepend := "${THISDIR}:"

AUV_PREEMPT_RT ??= "1"

SRC_URI:append = " \
    file://auv/can.cfg \
    file://auv/timing.cfg \
    file://auv/usb-serial.cfg \
    ${@oe.utils.conditional('AUV_PREEMPT_RT', '1', 'file://auv/rt.cfg', '', d)} \
"

python () {
    if d.getVar('AUV_PREEMPT_RT') not in ('0', '1'):
        bb.fatal("AUV_PREEMPT_RT must be 0 or 1")
}

# Every option of these fragments must reach the final .config as
# written; a mismatch stops the build. The base layer checks its own
# fragments the same way.
AUV_FRAGMENT_DIR := "${THISDIR}"

python do_kernel_configcheck:append() {
    # No import: this body is pasted into the original function.
    auv_dir = d.getVar('AUV_FRAGMENT_DIR')
    auv_config = {}
    with open(os.path.join(d.getVar('B'), '.config')) as f:
        for line in f:
            line = line.rstrip('\n')
            if line.startswith('CONFIG_') and '=' in line:
                k, v = line.split('=', 1)
                auv_config[k] = v
            elif line.startswith('# CONFIG_') and line.endswith(' is not set'):
                auv_config[line[2:-11]] = 'n'
    auv_errors = []
    auv_checked = 0
    for uri in (d.getVar('SRC_URI') or '').split():
        if not uri.startswith('file://auv/') or not uri.endswith('.cfg'):
            continue
        rel = uri[len('file://'):]
        with open(os.path.join(auv_dir, rel)) as f:
            for n, line in enumerate(f, 1):
                line = line.strip()
                if line.startswith('CONFIG_') and '=' in line:
                    k, want = line.split('=', 1)
                elif line.startswith('# CONFIG_') and line.endswith(' is not set'):
                    k, want = line[2:-11], 'n'
                else:
                    continue
                auv_checked += 1
                got = auv_config.get(k, 'n')
                if got != want:
                    auv_errors.append('%s:%d %s wanted %s, .config %s' % (rel, n, k, want, got))
    if auv_errors:
        bb.fatal('AUV fragments not applied:\n  ' + '\n  '.join(auv_errors))
    bb.note('AUV fragments: %d options checked, all applied' % auv_checked)
}
