################################################################################
#
# ldns (for drill)
#
################################################################################

LDNS_VERSION = 1.8.4
LDNS_SITE = https://www.nlnetlabs.nl/downloads/ldns
LDNS_LICENSE = BSD-3-Clause
LDNS_LICENSE_FILES = LICENSE
LDNS_DEPENDENCIES = host-pkgconf openssl
LDNS_CONF_OPTS = \
	--with-ssl=$(STAGING_DIR)/usr \
	--with-drill \
	--without-examples \
	--without-pyldns \
	--without-p5-dns-ldns \
	--disable-gost \
	--with-trust-anchor=/usr/local/addons/tools/share/ldns/root.key
LDNS_CONF_ENV = LIBS="`$(PKG_CONFIG_HOST_BINARY) --libs --static libcrypto`"
LDNS_INSTALL_TARGET_OPTS = DESTDIR=$(TARGET_DIR) install-drill

# a static link resolves left to right: libcrypto.a (pulled in by libldns.la, last on the line)
# needs zlib after it, so the libraries are named once more after libldns.la
define LDNS_STATIC_LINK_ORDER
	$(SED) 's|-o \(.*\) $$(top_builddir)/libldns.la$$|-o \1 $$(top_builddir)/libldns.la $$(LIBSSL_LIBS) $$(LIBS)|' $(@D)/Makefile
endef
LDNS_POST_CONFIGURE_HOOKS += LDNS_STATIC_LINK_ORDER

$(eval $(autotools-package))
