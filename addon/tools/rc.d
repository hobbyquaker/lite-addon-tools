#!/bin/sh
#
#   rc.d script of lite-addon-tools (MIT). Linked as /usr/local/etc/config/rc.d/tools. The addon
#   runs nothing: start and stop do nothing (no status: the unit's own state is the truth), info
#   names it for the Addons page, uninstall removes the tree.
#

ADDON=tools
NAME="Admin-Werkzeuge"
ADDON_DIR=/usr/local/addons/$ADDON

VERSION_ADDON=unknown
[ -r $ADDON_DIR/versions ] && . $ADDON_DIR/versions

case "$1" in
    init|start|stop|restart) ;;
    info)
        echo "Info: <div>$NAME: socat, tcpdump, strace, nmap, htop, iotop, nano, mtr, iperf3, drill, ss, iftop, arp-scan, tmux, ncdu, picocom, lsof, pstree, mmc, gdbserver</div>"
        echo "Name: $NAME"
        echo "Version: $VERSION_ADDON"
        echo "Operations: uninstall"
        ;;
    uninstall)
        # openccu-lite runs this as the addon's user and removes the links and the empty
        # directory itself afterwards
        rm -rf $ADDON_DIR/bin $ADDON_DIR/share $ADDON_DIR/etc $ADDON_DIR/www $ADDON_DIR/rc.d $ADDON_DIR/versions
        logger -t $ADDON -p daemon.info "Uninstalled $ADDON" 2>/dev/null
        ;;
    *) exit 0 ;;
esac
exit 0
