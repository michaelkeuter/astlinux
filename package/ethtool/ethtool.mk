#############################################################
#
# ethtool
#
#############################################################

ETHTOOL_VERSION = 3.12.1
ETHTOOL_SITE = http://www.kernel.org/pub/software/network/ethtool

$(eval $(call AUTOTARGETS,package,ethtool))
