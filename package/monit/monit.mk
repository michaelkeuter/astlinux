################################################################################
#
# monit
#
################################################################################

MONIT_VERSION = 5.10
MONIT_SITE = http://mmonit.com/monit/dist
#
# Touching Makefile.am:
MONIT_AUTORECONF = YES

MONIT_CONF_ENV = \
	libmonit_cv_setjmp_available=yes \
	libmonit_cv_vsnprintf_c99_conformant=yes

MONIT_CONF_OPT += \
	--sysconfdir=/etc/monit \
	--without-pam

ifeq ($(BR2_PACKAGE_OPENSSL),y)
MONIT_CONF_OPT += --with-ssl-dir=$(STAGING_DIR)/usr
MONIT_DEPENDENCIES += openssl
else
MONIT_CONF_OPT += --without-ssl
endif

ifeq ($(BR2_LARGEFILE),y)
MONIT_CONF_OPT += --with-largefiles
else
MONIT_CONF_OPT += --without-largefiles
endif

define MONIT_INSTALL_TARGET_CMDS
	$(INSTALL) -m 0755 -D $(@D)/monit $(TARGET_DIR)/usr/sbin/monit
	$(INSTALL) -m 0600 -D $(@D)/monitrc $(TARGET_DIR)/stat/etc/monit/monit.d/services
	$(SED) '1,/^## Services/ d' \
	    -e '/^## Includes/,$$ d' \
		$(TARGET_DIR)/stat/etc/monit/monit.d/services
	$(INSTALL) -m 0755 -D package/monit/monit.init $(TARGET_DIR)/etc/init.d/monit
	ln -sf /tmp/etc/monit $(TARGET_DIR)/etc/monit
	ln -sf ../../init.d/monit $(TARGET_DIR)/etc/runlevels/default/S75monit
	ln -sf ../../init.d/monit $(TARGET_DIR)/etc/runlevels/default/K15monit
endef

define MONIT_UNINSTALL_TARGET_CMDS
	rm -f $(TARGET_DIR)/usr/sbin/monit
	rm -rf $(TARGET_DIR)/stat/etc/monit
	rm -f $(TARGET_DIR)/etc/init.d/monit
	rm -f $(TARGET_DIR)/etc/monit
	rm -f $(TARGET_DIR)/etc/runlevels/default/S75monit
	rm -f $(TARGET_DIR)/etc/runlevels/default/K15monit
endef

$(eval $(call AUTOTARGETS,package,monit))