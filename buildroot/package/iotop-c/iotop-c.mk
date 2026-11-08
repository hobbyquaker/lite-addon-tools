################################################################################
#
# iotop-c
#
################################################################################

IOTOP_C_VERSION = 1.33
IOTOP_C_SOURCE = iotop-$(IOTOP_C_VERSION).tar.xz
IOTOP_C_SITE = https://github.com/Tomas-M/iotop/releases/download/v$(IOTOP_C_VERSION)
IOTOP_C_LICENSE = GPL-2.0+
IOTOP_C_LICENSE_FILES = COPYING
IOTOP_C_DEPENDENCIES = ncurses host-pkgconf

# NO_FLTO: no LTO with the external toolchain's static archives; HAVELPIE=no: -pie and -static
# do not mix (a command-line variable overrides the Makefile's own probe)
define IOTOP_C_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)" \
		PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
		NO_FLTO=1 HAVELPIE=no
endef

define IOTOP_C_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/iotop $(TARGET_DIR)/usr/sbin/iotop
endef

$(eval $(generic-package))
