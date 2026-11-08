################################################################################
#
# lite-tools-paths: the addon's own tree as the tools' data directory
#
# Not a package: appended to Buildroot's packages after their .mk files (BR2_EXTERNAL's .mk
# files are read last; the variables are used in the recipes, so the additions count). The
# addon lives in /usr/local/addons/tools; the data the tools look up at run time is shipped in
# its share/ and compiled in here, so no wrapper is needed.
#
################################################################################

LITE_TOOLS_PREFIX = /usr/local/addons/tools

# htop, nano, tmux, ncdu, iftop, mtr, iotop: the addon's terminfo first, then the system's
NCURSES_CONF_OPTS += \
	--with-terminfo-dirs=$(LITE_TOOLS_PREFIX)/share/terminfo:/usr/share/terminfo:/etc/terminfo:/lib/terminfo

# nmap: nmap-services, nmap-os-db, nmap-mac-prefixes, ... (the build only; installed as usual)
NMAP_MAKE_OPTS += nmapdatadir=$(LITE_TOOLS_PREFIX)/share/nmap

# arp-scan: ieee-oui.txt (pkgdatadir) and mac-vendor.txt ($(sysconfdir)/arp-scan, spelled out in
# its AM_CPPFLAGS)
ARP_SCAN_MAKE_OPTS += \
	pkgdatadir=$(LITE_TOOLS_PREFIX)/share/arp-scan \
	sysconfdir=$(LITE_TOOLS_PREFIX)/etc

# iperf3: no openssl (its --rsa-public-key authentication); a static libcrypto is 4 MB a binary
IPERF3_CONF_OPTS += --without-openssl
