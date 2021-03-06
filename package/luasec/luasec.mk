#############################################################
#
# luasec
#
#############################################################

LUASEC_VERSION = 0.5.1
LUASEC_SOURCE = luasec-prosody-$(LUASEC_VERSION).tar.gz
LUASEC_SITE = http://files.astlinux-project.org
LUASEC_DEPENDENCIES = lua openssl luasocket

define LUASEC_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) linux \
		INC_PATH="" \
		LIB_PATH="" \
		LIBDIR="-L$(STAGING_DIR)/usr/lib/ -L$(@D)/src/luasocket" \
		CC="$(TARGET_CC)" \
		LD="$(TARGET_LD) -shared"
endef

define LUASEC_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) install \
		LUACPATH="$(TARGET_DIR)/usr/lib/lua" \
		LUAPATH="$(TARGET_DIR)/usr/share/lua"
endef

define LUASEC_UNINSTALL_TARGET_CMDS
	rm -rf "$(TARGET_DIR)/usr/share/lua/ssl"
	rm -f "$(TARGET_DIR)/usr/share/lua/ssl.lua"
	rm -f "$(TARGET_DIR)/usr/lib/lua/ssl.so"
endef

define LUASEC_CLEAN_CMDS
	$(MAKE) -C $(@D) -f makefile clean
endef

$(eval $(call GENTARGETS,package,luasec))
