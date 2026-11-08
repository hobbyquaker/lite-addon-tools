# lite-addon-tools

*[English](README.en.md)*

> **Noch nicht veröffentlicht.** Das Addon braucht eine openccu-lite-Version, die `runtime.bin` aus dem Manifest
> kennt (die Werkzeuge im Suchpfad); sie kommt mit dem nächsten openccu-lite-Release. Auf älteren Systemen lässt es
> sich installieren, die Werkzeuge werden dann mit vollem Pfad aufgerufen (`/usr/local/addons/tools/bin/htop`).

**Werkzeuge für Fehlersuche und Verwaltung** auf einem [openccu-lite](https://github.com/hobbyquaker/openccu-lite)-System,
für die Arbeit über ssh. Alle Programme sind **statisch gebaut** (Buildroot mit der musl-Toolchain von Bootlin) und
hängen von nichts im System ab; das Addon startet **keinen Dienst** und öffnet **keinen Port**.

## Die Werkzeuge

| Netz | | System | |
| --- | --- | --- | --- |
| `socat` | Verbindungen und Sockets verbinden | `strace` | Systemaufrufe eines Prozesses |
| `tcpdump` | Pakete mitschneiden | `htop` | Prozesse, interaktiv |
| `nmap` | Ports und Dienste im Netz finden | `iotop` | Ein-/Ausgabe je Prozess |
| `mtr` | traceroute und ping in einem | `nano` | Editor |
| `iperf3` | Durchsatz messen | `tmux` | Sitzungen, die eine getrennte ssh-Verbindung überleben |
| `drill` | DNS-Abfragen (statt `dig`) | `ncdu` | Wo ist der Platz hin? |
| `ss` | offene Sockets (iproute2) | `picocom` | serielle Konsole |
| `iftop` | Verkehr je Verbindung | `lsof` | offene Dateien (das volle lsof) |
| `arp-scan` | Geräte im LAN finden | `pstree`, `prtstat` | psmisc |
| | | `mmc` | eMMC/SD-Karte abfragen (mmc-utils) |
| | | `gdbserver` | Fehlersuche mit einem gdb auf dem PC |

Die Versionen stehen in `/usr/local/addons/tools/share/VERSIONS` und in den Release-Notizen; es sind die, die das
Buildroot des Releases mitbringt.

## Benutzung

Über ssh als root anmelden (ssh muss im System eingeschaltet sein). Die meisten Werkzeuge
brauchen root: `tcpdump`, `iftop`, `arp-scan`, `mtr`, `strace`, `iotop`, `lsof` für fremde Prozesse.

```sh
htop
tcpdump -ni eth0 port 2001
mtr -rwc 20 192.168.1.1
iotop -o
tmux new -s arbeit        # nach einer getrennten Verbindung: tmux attach -t arbeit
```

- **Suchpfad:** das System hängt `/usr/local/addons/tools/bin` an den Suchpfad der Anmelde-Shell **an**. Gibt es
  einen Befehl schon im System (BusyBox), geht der des Systems vor. Das betrifft `lsof`: das volle lsof des Addons
  rufen Sie mit `/usr/local/addons/tools/bin/lsof` auf (oder `alias lsof=/usr/local/addons/tools/bin/lsof`). `killall`
  und `fuser` aus psmisc sind deshalb nicht dabei; die von BusyBox reichen.
- **iotop** zeigt die Wartezeiten (SWAPIN, IO>) nur, wenn das Delay-Accounting des Kernels an ist:
  `sysctl kernel.task_delayacct=1` (bis zum nächsten Neustart). Die Ein-/Ausgabe je Prozess zeigt es immer.
- **nmap** ist ohne seine Skript-Engine (NSE) gebaut: Port- und Dienst-Erkennung ja, `--script` nein.
- **drill** statt `dig`: Buildroots bind lässt sich nicht statisch bauen. `drill example.org`, `drill -T example.org`
  (der Weg von der Wurzel), `drill -x 192.0.2.1`.
- **Terminal:** die Beschreibungen gängiger Terminals (xterm, xterm-256color, screen, tmux, putty, rxvt, kitty, foot, wezterm, st,
  alacritty, linux) bringt das Addon mit.

## Deinstallieren

Auf der Addons-Seite. Das Addon legt nichts außerhalb von `/usr/local/addons/tools` an (außer den Verweisen, die das
System selbst wieder entfernt) und hinterlässt nichts.

## Versionen

`<Buildroot>.<n>`, z. B. `2026.08.1.1`: das Buildroot, mit dem gebaut wurde (immer mit Punkt-Release, `2026.08` ist
`2026.08.0`), und die laufende Nummer der Releases auf diesem Buildroot. Wer die Version liest, weiß damit, welche
Werkzeug-Versionen drin sind; die Reihenfolge ist die numerische, die das System beim Update-Vergleich verwendet.
Solange das Addon nicht veröffentlicht ist, tragen die Versionen ein `-dev` (`2026.08.1.1-dev`).

Neue Versionen kommen von selbst: ein Workflow liest täglich, welches Buildroot das neueste openccu-lite-Release
verwendet, am Monatsersten auch das neueste Punkt-Release dieser Buildroot-Reihe; ist es neuer, baut er beide
Architekturen, testet jedes Programm und veröffentlicht das Release. Schlägt etwas fehl, öffnet er ein Issue statt
eines Releases.

## Bauen

```sh
VERSION=0.0.0-dev scripts/build.sh          # aarch64 und x86_64, Pakete in dist/
ARCHES=x86_64 scripts/build.sh              # eine Architektur
scripts/smoke.sh dist/tools-*.tar.gz        # der Test (aarch64 unter qemu-user)
```

Braucht, was Buildroot braucht (gcc, make, wget, cpio, rsync, bc, file, python3), und `qemu-user` für den Test.
`buildroot/` ist ein BR2_EXTERNAL-Baum: die Konfiguration (`configs/`), htop statisch, iotop-c und ldns (drill), die
Buildroot nicht oder nur dynamisch baut, und die Datenpfade im Addon (`package/lite-tools-paths`).

## Lizenz

Die Paketierung (Skripte, Manifest, Workflows): MIT, siehe [LICENSE](LICENSE). Die Werkzeuge stehen unter ihren
eigenen Lizenzen (GPL-2.0+, BSD und andere); die Texte liegen im Paket unter `share/licenses`, die Quellen jedes
Releases als `tools-sources-<version>.tar` beim Release.
