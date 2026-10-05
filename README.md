# yocto-auv-swarm-hardened

Hardened operating system for an underwater drone cloud: AUV swarm,
semi-submersible gateway, unmanned surface vehicle (USV), satellite/cloud link.

Status: design phase. The build will start once the
[yocto-jetson-tegra-hardened](https://github.com/roastercode/yocto-jetson-tegra-hardened)
base is finalized.

## Relationship with yocto-jetson-tegra-hardened

Separate repository, distinct project, same foundation. The base is not copied:
it is consumed as a pinned layer dependency. Fixes to the foundation (hardening,
kernel analysis tools, CVE tracking) are made in the base and flow down here by
simply updating the pin.

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

## Version

See `VERSION` and `CHANGELOG.md`.
