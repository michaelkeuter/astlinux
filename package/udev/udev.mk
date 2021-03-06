#############################################################
#
# udev
#
#############################################################
UDEV_VERSION = 173
UDEV_SOURCE = udev-$(UDEV_VERSION).tar.bz2
UDEV_SITE = $(BR2_KERNEL_MIRROR)/linux/utils/kernel/hotplug/
UDEV_INSTALL_STAGING = YES

UDEV_CONF_OPT =			\
	--sbindir=/sbin		\
	--with-rootlibdir=/lib	\
	--libexecdir=/lib/udev	\
	--with-usb-ids-path=/usr/share/usb.ids \
	--with-pci-ids-path=/usr/share/pci.ids \
	--with-firmware-path=/lib/firmware \
	--disable-introspection

UDEV_DEPENDENCIES = host-gperf host-pkg-config

ifeq ($(BR2_PACKAGE_UDEV_ALL_EXTRAS),y)
UDEV_DEPENDENCIES += libusb libusb-compat acl usbutils hwdata libglib2
UDEV_CONF_OPT +=							\
	--enable-udev_acl
else
UDEV_CONF_OPT +=		\
	--disable-gudev
endif

define UDEV_INSTALL_INITSCRIPT
	echo 'udev_run="/var/run/udev"' >> $(TARGET_DIR)/etc/udev/udev.conf
endef
UDEV_POST_INSTALL_TARGET_HOOKS += UDEV_INSTALL_INITSCRIPT

define UDEV_INSTALL_USBTTY
	$(INSTALL) -m 0644 -D package/udev/usbtty/usbtty.rules $(TARGET_DIR)/etc/udev/rules.d/usbtty.rules
	$(INSTALL) -m 0755 -D package/udev/usbtty/usb-getty $(TARGET_DIR)/usr/share/usbtty/usb-getty
	$(INSTALL) -m 0755 -D package/udev/usbtty/usb-getty-background $(TARGET_DIR)/usr/share/usbtty/usb-getty-background
endef
UDEV_POST_INSTALL_TARGET_HOOKS += UDEV_INSTALL_USBTTY

$(eval $(call AUTOTARGETS,package,udev))
