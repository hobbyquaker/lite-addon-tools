################################################################################
#
# htop-static: package/htop's version and source, linked statically
#
################################################################################

HTOP_STATIC_VERSION = $(HTOP_VERSION)
HTOP_STATIC_SOURCE = $(HTOP_SOURCE)
HTOP_STATIC_SITE = $(HTOP_SITE)
HTOP_STATIC_DL_SUBDIR = htop
HTOP_STATIC_DEPENDENCIES = ncurses
HTOP_STATIC_LICENSE = GPL-2.0+
HTOP_STATIC_LICENSE_FILES = COPYING
HTOP_STATIC_CONF_ENV = \
	HTOP_NCURSES_CONFIG_SCRIPT=$(STAGING_DIR)/usr/bin/$(NCURSES_CONFIG_SCRIPTS) \
	ac_cv_prog_cc_c99=-std=gnu99
# --enable-static: htop links its binary statically (and drops the dlopen()ed extras)
HTOP_STATIC_CONF_OPTS = \
	--enable-static \
	--enable-unicode \
	--disable-hwloc \
	--disable-capabilities \
	--disable-sensors \
	--disable-delayacct

$(eval $(autotools-package))

# the hash file is package/htop's, so a Buildroot that moves htop moves this one too
HTOP_STATIC_HASH_FILES = $(TOPDIR)/package/htop/htop.hash
