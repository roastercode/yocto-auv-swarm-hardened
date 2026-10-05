# yocto-auv-swarm-hardened

Hardened operating system for an underwater drone cloud: AUV swarm,
semi-submersible gateway, unmanned surface vehicle (USV), satellite/cloud link.

Status: layer in place, first build pending. See Status below.

## Relationship with yocto-jetson-tegra-hardened

This repository is a fork of
[yocto-jetson-tegra-hardened](https://github.com/roastercode/yocto-jetson-tegra-hardened),
with its full history merged. Fixes to the base are brought in with:

    git fetch jetson && git merge jetson/main

The layer collection is renamed `auv-swarm-hardened`. It replaces the
base in `bblayers.conf`: never load both.

## Architecture

~~~text
              CONTROL CENTER / CLOUD
                       |
             SAT / 4G-5G / Internet
                       |
                      USV          GNSS, gateway, fleet coordination
                       |
                   RF / Wi-Fi
                       |
               SEMI-SUBMERSIBLE    RF/SAT mast above water, edge compute,
                       |           USBL, DTN gateway
             +---------+---------+
             |                   |
          OPTICAL            ACOUSTIC
       (rendezvous)        (long range)
             |                   |
        nearby AUVs         distant AUVs
             \                   /
              +--- AUV swarm ---+
~~~

Three tiers:

- **Control center**: global planning, maps, history, supervision.
- **Maritime edge** (USV, semi-sub): relay, storage, data fusion, replanning,
  GNSS navigation reference to USBL.
- **Underwater edge** (AUVs): each AUV is autonomous; several AUVs form a
  temporary micro-cloud.

## Operating configurations

Stealth is not a property of the system, it is a mode (EMCON).

| Configuration | Surface | Channels | Stealth |
|---|---|---|---|
| Open | USV | acoustic, optical, RF, SAT | low |
| Discreet | low-profile semi-sub | optical, LPI acoustic emissions | medium |
| Autonomous silent | none | optical rendezvous, exceptional surfacing | high |

Silent mode: optical only while submerged, regular regrouping within optical
range, surfacing (GNSS fix, SAT burst or short-range radio) only when the link
loss with the group exceeds a threshold.

## Communications

- **Acoustic**: long range, data rate from about a hundred bit/s to a few kbit/s,
  about 0.67 s propagation delay per km. Interoperability target: JANUS (STANAG 4748).
- **Optical**: a few tens of meters, high data rate, pointing required.
  A rendezvous link, not a permanent link.
- **RF / SAT**: only from the surface or a mast.
- **DTN**: Bundle Protocol v7 (RFC 9171) for store-and-forward between vehicles,
  with per-message priority and lifetime.
- **ROS 2 / Zenoh**: inside each vehicle and over wide links only.
  Never over the acoustic link.

## Navigation

- Inertial + DVL in open mode; pure inertial in silent mode (much higher drift).
- USBL position fixes from a GNSS platform (USV or semi-sub).
- Without a surface vehicle: passive options through gravity or magnetic map matching.
- Stable local clock (CSAC type) for synchronization and acoustic ranging.

## OS foundation

- Hardened Yocto (yocto-jetson-tegra-hardened base), PREEMPT_RT kernel.
- Separate safety MCU (Zephyr): propulsion, ballast, drop weight release, watchdog.
- **Kernel-enforced EMCON**: mandatory access policy (LSM) denying access to
  transmitter drivers according to the current level; level changes restricted to
  a trusted entity (signed mission or authenticated order); transitions logged.
- Persistent DTN store resilient to power loss.

## Open work items

- **Optical communication**: to be improved, as optical modems span very different
  quality levels (LED or laser, PIN/APD/PMT receivers, blue or green wavelength
  depending on water type, modulation and forward error correction). Lead: wide-beam
  LED acquisition, then pointed laser transfer.
- **Rendezvous under inertial drift**: optical range versus position uncertainty.
- **Authentication over short acoustic frames**: an Ed25519 signature (64 bytes)
  often exceeds the payload; replay protection without a reliable clock.
- **Stealth**: signature of the mast, emissions and propulsion.

## Building

Layers: those of the base (openembedded-core, bitbake, meta-yocto,
meta-openembedded with meta-oe, meta-python and meta-networking,
meta-selinux, meta-tegra), this layer instead of the base, and:

- meta-ros: `meta-ros-common`, `meta-ros2`, `meta-ros2-jazzy`;
- meta-zenoh.

Their commits are pinned in `conf/layers.pin`.

Settings in `conf/local.conf`, as for the base, with:

    DISTRO = "poky-auv-hardened"
    AUV_PREEMPT_RT = "1"   # default; "0" builds without PREEMPT_RT

Builds go through `bin/jetson-build.sh`, inherited from the base:

    BUILD_DIR=/path/to/build-auv-orin bin/jetson-build.sh auv-swarm-image

A detached build is followed live with `bin/jetson-follow.py`; with
`--pid`, it stops when the build ends and exits 0 only if it succeeded:

    BUILD_DIR=... nohup bin/jetson-build.sh auv-swarm-image > LOG 2>&1 &
    bin/jetson-follow.py --build BUILDDIR --pid $! LOG

## What the image carries

- ROS 2 Jazzy (`ros-core` with tf2; not `ros-base`, whose geometry2
  pulls the bullet physics engine and OpenGL) with `rmw_zenoh_cpp` as middleware, set by
  `/etc/profile.d/auv-ros.sh`, and the Zenoh router `zenohd`. Zenoh is
  pinned to 1.8.0, the version rmw_zenoh is validated against upstream,
  and rmw_zenoh uses it from meta-zenoh rather than vendoring its own.
- Navigation: gpsd, robot_localization, nmea_navsat_driver.
- Timing: chrony, linuxptp, pps-tools.
- Fieldbus: can-utils.
- The base layer's analysis tooling (development image).

Kernel, on top of the base configuration: PREEMPT_RT, SocketCAN with USB
CAN adapters, PPS and PTP, USB serial adapters. Every option is checked
against the final `.config`; a mismatch stops the build.

## Status

`auv-swarm-image` builds for `jetson-agx-orin-devkit`: ext4 root
filesystem, tegraflash archive, debug symbols, SPDX 3.0 SBOM and CVE
report. The kernel fragments are checked against the final `.config`.
Nothing has been flashed or run on a Jetson yet.

Not yet included, each needing its own recipe and tests:

- DTN: a uD3TN recipe (Bundle Protocol v7, SQLite persistent storage).
- Kernel-enforced EMCON (LSM).
- Acoustic ROS 2 middleware (rmw_desert): GPL-3.0, and useless without
  the DESERT framework, which is not packaged.

PREEMPT_RT with NVIDIA's out-of-tree drivers is untested.

## License

MIT, inherited from the base. See `LICENSE`.

## Version

See `VERSION` and `CHANGELOG.md`.
