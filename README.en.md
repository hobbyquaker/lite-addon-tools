# lite-addon-tools

*[Deutsch](README.md)*

**Troubleshooting and administration tools** for an [openccu-lite](https://github.com/openccu-lite/openccu-lite)
system, for work over ssh. Every program is **built statically** (Buildroot with Bootlin's musl toolchain) and depends
on nothing in the system; the addon starts **no service** and opens **no port**.

## The tools

| Network | | System | |
| --- | --- | --- | --- |
| `socat` | connect sockets and streams | `strace` | a process's system calls |
| `tcpdump` | capture packets | `htop` | processes, interactive |
| `nmap` | find ports and services on the network | `iotop` | I/O per process |
| `mtr` | traceroute and ping in one | `nano` | editor |
| `iperf3` | measure throughput | `tmux` | sessions that survive a dropped ssh connection |
| `drill` | DNS queries (instead of `dig`) | `ncdu` | where did the space go? |
| `ss` | open sockets (iproute2) | `picocom` | serial console |
| `iftop` | traffic per connection | `lsof` | open files (the full lsof) |
| `arp-scan` | find devices on the LAN | `pstree`, `prtstat` | psmisc |
| | | `mmc` | query the eMMC/SD card (mmc-utils) |
| | | `gdbserver` | debugging with a gdb on the PC |

The versions are in `/usr/local/addons/tools/share/VERSIONS` and in the release notes; they are the ones the release's
Buildroot carries.

## Installation

Needs **openccu-lite 1.2.1** or later, the first version that puts an addon's tools on the search path; older systems
refuse the install. Install the package `tools-<arch>-<version>.tar.gz` (`aarch64` for a Raspberry Pi 3/4/5, `x86_64`
for the virtual appliance and PCs) from the [releases page](https://github.com/openccu-lite/lite-addon-tools/releases)
through the system's Addons page. The tools are there in the next ssh login; a shell already open keeps its search
path.

## Use

Log in over ssh as root (ssh must be switched on in the system). Most tools need root: `tcpdump`,
`iftop`, `arp-scan`, `mtr`, `strace`, `iotop`, `lsof` for other users' processes.

```sh
htop
tcpdump -ni eth0 port 2001
mtr -rwc 20 192.168.1.1
iotop -o
tmux new -s work          # after a dropped connection: tmux attach -t work
```

- **Search path:** the system **appends** `/usr/local/addons/tools/bin` to the login shell's search path. Where the
  system already has a command (BusyBox), the system's comes first. That concerns `lsof`: call the addon's full lsof as
  `/usr/local/addons/tools/bin/lsof` (or `alias lsof=/usr/local/addons/tools/bin/lsof`). psmisc's `killall` and
  `fuser` are left out for that reason; BusyBox's do.
- **iotop** shows the wait times (SWAPIN, IO>) only with the kernel's delay accounting on:
  `sysctl kernel.task_delayacct=1` (until the next reboot). The I/O per process it always shows.
- **nmap** is built without its scripting engine (NSE): port and service detection yes, `--script` no.
- **drill** instead of `dig`: Buildroot's bind cannot be built statically. `drill example.org`, `drill -T example.org`
  (the path from the root), `drill -x 192.0.2.1`.
- **Terminal:** the addon brings the descriptions of common terminals (xterm, xterm-256color, screen, tmux, putty,
  rxvt, kitty, foot, wezterm, st, alacritty, linux).

## Uninstall

On the Addons page. The addon creates nothing outside `/usr/local/addons/tools` (but the links the system removes
itself) and leaves nothing behind.

## Versions

`<Buildroot>.<n>`, e.g. `2026.08.1.1`: the Buildroot it was built with (always with its point release, `2026.08` is
`2026.08.0`), and the number of the release on that Buildroot. The version tells which tool versions are inside; the
order is the numeric one the system's update check uses.

New versions come by themselves: a workflow reads once a day which Buildroot the newest openccu-lite release uses, on
the 1st of the month also the newest point release of that Buildroot series; when it is newer, it builds both
architectures, tests every program and publishes the release. When something fails it opens an issue instead.

## Build

```sh
VERSION=0.0.0-dev scripts/build.sh          # aarch64 and x86_64, packages in dist/
ARCHES=x86_64 scripts/build.sh              # one architecture
scripts/smoke.sh dist/tools-*.tar.gz        # the test (aarch64 under qemu-user)
```

Needs what Buildroot needs (gcc, make, wget, cpio, rsync, bc, file, python3), and `qemu-user` for the test.
`buildroot/` is a BR2_EXTERNAL tree: the configuration (`configs/`), htop static, iotop-c and ldns (drill), which
Buildroot does not build or builds only dynamically, and the data paths in the addon (`package/lite-tools-paths`).
`buildroot-patches/` holds the changes to Buildroot itself, applied to its tree before the build: OpenSSL from the
3.5 LTS series instead of Buildroot's 3.6, which is out of support (used by `drill` and `nmap`).

## Licence

The packaging (scripts, manifest, workflows): MIT, see [LICENSE](LICENSE). The tools are under their own licences
(GPL-2.0+, BSD and others); the texts are in the package under `share/licenses`, the sources of each release as
`tools-sources-<version>.tar` with the release.
