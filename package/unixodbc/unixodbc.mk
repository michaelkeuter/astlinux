#############################################################
#
# unixodbc
#
#############################################################
UNIXODBC_VERSION = 2.3.3
UNIXODBC_SOURCE = unixODBC-$(UNIXODBC_VERSION).tar.gz
UNIXODBC_SITE = ftp://ftp.unixodbc.org/pub/unixODBC
UNIXODBC_DEPENDENCIES = host-bison host-flex libtool

UNIXODBC_INSTALL_STAGING = YES

UNIXODBC_CONF_OPT = \
	--disable-static \
	--disable-gui \
	--with-pic \
	--disable-drivers

define UNIXODBC_INSTALL_TARGET_CMDS
        cp -a $(STAGING_DIR)/usr/lib/libodbc*so* $(TARGET_DIR)/usr/lib/
	$(INSTALL) -m 0755 -D package/unixodbc/unixodbc.init $(TARGET_DIR)/etc/init.d/unixodbc
	$(INSTALL) -m 0755 -D $(STAGING_DIR)/usr/bin/isql $(TARGET_DIR)/usr/bin/isql
	$(INSTALL) -m 0755 -D $(STAGING_DIR)/usr/bin/odbcinst $(TARGET_DIR)/usr/bin/odbcinst
	ln -sf /tmp/etc/odbc.ini $(TARGET_DIR)/etc/odbc.ini
	ln -sf /tmp/etc/odbcinst.ini $(TARGET_DIR)/etc/odbcinst.ini
	ln -sf /tmp/etc/ODBCDataSources $(TARGET_DIR)/etc/ODBCDataSources
	ln -sf ../../init.d/unixodbc $(TARGET_DIR)/etc/runlevels/default/S00unixodbc
endef

define UNIXODBC_UNINSTALL_TARGET_CMDS
        rm -f $(TARGET_DIR)/usr/lib/libodbc*so*
        rm -f $(TARGET_DIR)/etc/init.d/unixodbc
        rm -f $(TARGET_DIR)/usr/bin/isql
        rm -f $(TARGET_DIR)/usr/bin/odbcinst
        rm -f $(TARGET_DIR)/etc/odbc.ini
        rm -f $(TARGET_DIR)/etc/odbcinst.ini
        rm -f $(TARGET_DIR)/etc/ODBCDataSources
        rm -f $(TARGET_DIR)/etc/runlevels/default/S00unixodbc
endef

$(eval $(call AUTOTARGETS,package,unixodbc))
