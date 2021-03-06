#############################################################
#
# mrouted
#
#
#############################################################
MROUTED_VERSION = 3.9.4
MROUTED_SOURCE = mrouted-$(MROUTED_VERSION).tar.bz2
MROUTED_SITE = http://ftp.vmlinux.org/pub/People/jocke/mrouted
MROUTED_DEPENDENCIES = host-bison

define MROUTED_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D)
endef

define MROUTED_INSTALL_TARGET_CMDS
	$(MAKE) prefix=/usr DESTDIR=$(TARGET_DIR) -C $(@D) install
endef

define MROUTED_UNINSTALL_TARGET_CMDS
	$(MAKE) prefix=/usr DESTDIR=$(TARGET_DIR) -C $(@D) uninstall
endef

define MROUTED_CLEAN_CMDS
	$(MAKE) -C $(@D) clean
endef

$(eval $(call GENTARGETS,package,mrouted))
