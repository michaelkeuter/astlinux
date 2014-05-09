#!/usr/bin/perl -w
#!/usr/local/bin/perl -w
######################################################################
# $Id: ddclient 157 2013-12-26 09:02:05Z wimpunk $
#
# DDCLIENT - a Perl client for updating DynDNS information
#
# Author: Paul Burry (paul+ddclient@burry.ca)
# ddclient-developers: see https://sourceforge.net/project/memberlist.php?group_id=116817
#
# website: http://ddclient.sf.net
#
# Support for multiple IP numbers added by
# Astaro AG, Ingo Schwarze <ischwarze-OOs/4mkCeqbQT0dZR+AlfA@public.gmane.org> September 16, 2008
#
######################################################################
require 5.004;
use strict;
use Getopt::Long;
use Sys::Hostname;
use IO::Socket;

my ($VERSION) = q$Revision: 157 $ =~ /(\d+)/;

my $version  = "3.8.2";
my $programd  = $0; 
$programd =~ s%^.*/%%;
my $program   = $programd;
$program  =~ s/d$//;
my $now       = time;
my $hostname  = hostname();
my $etc       = ($program =~ /test/i) ? './'   : '/etc/ddclient/';
my $cachedir  = ($program =~ /test/i) ? './'   : '/var/cache/ddclient/';
my $savedir   = ($program =~ /test/i) ? 'URL/' : '/tmp/';
my $msgs      = '';
my $last_msgs = '';

use vars qw($file $lineno);
local $file   = '';
local $lineno = '';

$ENV{'PATH'} = (exists($ENV{PATH}) ? "$ENV{PATH}:" : "") . "/sbin:/usr/sbin:/bin:/usr/bin:/etc:/usr/lib:";

sub T_ANY	{'any'};
sub T_STRING	{'string'};
sub T_EMAIL	{'e-mail address'};
sub T_NUMBER	{'number'};
sub T_DELAY	{'time delay (ie. 1d, 1hour, 1m)'};
sub T_LOGIN	{'login'};
sub T_PASSWD	{'password'};
sub T_BOOL	{'boolean value'};
sub T_FQDN	{'fully qualified host name'};
sub T_OFQDN	{'optional fully qualified host name'};
sub T_FILE	{'file name'};
sub T_FQDNP	{'fully qualified host name and optional port number'};
sub T_PROTO	{'protocol'}
sub T_USE	{'ip strategy'}
sub T_IF        {'interface'}
sub T_PROG      {'program name'}
sub T_IP        {'ip'}
sub T_POSTS	{'postscript'};

## strategies for obtaining an ip address.
my %builtinweb = (
   'dyndns'       => { 'url' => 'http://checkip.dyndns.org/', 'skip' =>
   'Current IP Address:', },
   'dnspark'      => { 'url' => 'http://ipdetect.dnspark.com/', 'skip' => 'Current Address:', },
   'loopia'       => { 'url' => 'http://dns.loopia.se/checkip/checkip.php', 'skip' => 'Current Address:', },
);
my %builtinfw = (
    'watchguard-soho'        => {
				  'name' => 'Watchguard SOHO FW',
				  'url'  => '/pubnet.htm',
				  'skip' => 'NAME=IPAddress VALUE=',
			        },
    'netopia-r910'           => {
				  'name' => 'Netopia R910 FW',
				  'url'  => '/WanEvtLog',
				  'skip' => 'local:',                
			        },
    'smc-barricade'          => {
				  'name' => 'SMC Barricade FW',
				  'url'  => '/status.htm',
				  'skip' => 'IP Address',
			        },
    'smc-barricade-alt'      => {
				  'name' => 'SMC Barricade FW (alternate config)',
				  'url'  => '/status.HTM',
				  'skip' => 'WAN IP',
			        },
    'smc-barricade-7401bra'  => {
				  'name' => 'SMC Barricade 7401BRA FW',
				  'url'  => '/admin/wan1.htm',
				  'skip' => 'IP Address',
			        },
    'netgear-rt3xx'          => {
				  'name' => 'Netgear FW',
				  'url'  => '/mtenSysStatus.html',
				  'skip' => 'IP Address',
			        },
    'elsa-lancom-dsl10'      => {
				  'name' => 'ELSA LanCom DSL/10 DSL FW',
				  'url'  => '/config/1/6/8/3/',
				  'skip' => 'IP.Address',
			        },
    'elsa-lancom-dsl10-ch01' => { 
	 			  'name' => 'ELSA LanCom DSL/10 DSL FW (isdn ch01)',
				  'url'  => '/config/1/6/8/3/',
				  'skip' => 'IP.Address.*?CH01',     
			        },  
    'elsa-lancom-dsl10-ch02' => { 
	                          'name' => 'ELSA LanCom DSL/10 DSL FW (isdn ch01)',
				  'url'  => '/config/1/6/8/3/',
				  'skip' => 'IP.Address.*?CH02',
			        },  
    'linksys'                => {
	                          'name' => 'Linksys FW',
				  'url'  => '/Status.htm',
				  'skip' => 'WAN.*?Address',      
			        },
    'linksys-ver2'                => {
	                          'name' => 'Linksys FW version 2',
				  'url'  => '/RouterStatus.htm',
				  'skip' => 'WAN.*?Address',      
			        },
    'linksys-ver3'                => {
	                          'name' => 'Linksys FW version 3',
                                 'url'  => '/Status_Router.htm',
				  'skip' => 'WAN.*?Address',      
			        },
     'linksys-wrt854g'        => {
                                 'name' => 'Linksys WRT854G FW',
                                 'url'  => '/Status_Router.asp',
                                 'skip' => 'IP Address:',
                               },
    'maxgate-ugate3x00'      => {
	                          'name' => 'MaxGate UGATE-3x00 FW',
	                          'url'  => '/Status.htm',
				  'skip' => 'WAN.*?IP Address',
                                },
     'netcomm-nb3' => { 
				'name' => 'NetComm NB3', 
				'url' => '/MainPage?id=6', 
				'skip' => 'ppp-0', 
				}, 
    '3com-3c886a'            => {
    				  'name' => '3com 3c886a 56k Lan Modem',
                                  'url'  => '/stat3.htm',
                                  'skip' => 'IP address in use',     
                                },
    'sohoware-nbg800'        => {
    				  'name' => 'SOHOWare BroadGuard NBG800',
                                  'url'  => '/status.htm',
                                  'skip' => 'Internet IP',     
                                },
    'xsense-aero'	     => {
	                          'name' => 'Xsense Aero',
	                          'url'  => '/A_SysInfo.htm',
				  'skip' => 'WAN.*?IP Address',
                                },
    'alcatel-stp'            => {
				  'name' => 'Alcatel Speed Touch Pro',
				  'url'  => '/cgi/router/',
                                  'skip' => 'Brt',
				},
    'alcatel-510'            => {
                                  'name' => 'Alcatel Speed Touch 510',
                                  'url'  => '/cgi/ip/',
                                  'skip' => 'ppp',
                                },
    'allnet-1298'            => {
                                  'name' => 'Allnet 1298',
                                  'url'  => '/cgi/router/',
                                  'skip' => 'WAN',
                                },
    '3com-oc-remote812'      => {
    				  'name' => '3com OfficeConnect Remote 812',
                                  'url'  => '/callEvent',
                                  'skip' => '.*LOCAL',
                                },
    'e-tech'		     => {
				  'name' => 'E-tech Router',
				  'url'  => '/Status.htm',
				  'skip' => 'Public IP Address',
                              },
    'cayman-3220h'	     => {
				  'name' => 'Cayman 3220-H DSL',
				  'url'  => '/shell/show+ip+interfaces',
				  'skip' => '.*inet',
                              },
    'vigor-2200usb'           => {
				  'name' => 'Vigor 2200 USB',
				  'url'  => '/doc/online.sht',
				  'skip' => 'PPPoA',
			      },
    'dlink-614'            => {
				  'name' => 'D-Link DI-614+',
				  'url'  => '/st_devic.html',
				  'skip' => 'WAN',
			      },
    'dlink-604'            => {
				  'name' => 'D-Link DI-604',
				  'url'  => '/st_devic.html',
				  'skip' => 'WAN.*?IP.*Address',
			      },
    'olitec-SX200'            => {
				  'name' => 'olitec-SX200',
				  'url'  => '/doc/wan.htm',
				  'skip' => 'st_wan_ip[0] = "',
			      },
    'westell-6100'            => {
				  'name' => 'Westell C90-610015-06 DSL Router',
				  'url'  => '/advstat.htm',
				  'skip' => 'IP.+?Address',
			      },
     '2wire'                  => {
                                 'name' => '2Wire 1701HG Gateway',
                                 'url'  => '/xslt?PAGE=B01',
                                 'skip' => 'Internet Address:',
                               },
    'linksys-rv042-wan1' => {
        'name' => 'Linksys RV042 Dual Homed Router WAN Port 2',
        'url' => '/home.htm',
        'skip' => 'WAN1 IP',
    },
    'linksys-rv042-wan2' => {
        'name' => 'Linksys RV042 Dual Homed Router WAN Port 2',
        'url' => '/home.htm',
        'skip' => 'WAN2 IP',
    },
    'netgear-rp614' => {
        'name' => 'Netgear RP614 FW',
        'url' => '/sysstatus.html',
        'skip' => 'IP Address',
    },
    'watchguard-edge-x' => {
        'name' => 'Watchguard Edge X FW',
        'url' => '/netstat.htm',
        'skip' => 'inet addr:',
    },
    'dlink-524' => {
        'name' => 'D-Link DI-524',
        'url' => '/st_device.html',
        'skip' => 'WAN.*?Addres',
    },
    'rtp300' => {
        'name' => 'Linksys RTP300',
        'url' => '/cgi-bin/webcm?getpage=%2Fusr%2Fwww_safe%2Fhtml%2Fstatus%2FRouter.html',
        'skip' => 'Internet.*?IP Address',
    },
    'netgear-wpn824' => {
        'name' => 'Netgear WPN824 FW',
        'url' => '/RST_status.htm',
        'skip' => 'IP Address',
    },
    'linksys-wcg200' => {
        'name' => 'Linksys WCG200 FW',
        'url' => '/RgStatus.asp',
        'skip' => 'WAN.IP.*?Address',
    },
    'netgear-dg834g' => {
        'name' => 'netgear-dg834g',
        'url' => '/setup.cgi?next_file=s_status.htm&todo=cfg_init',
        'skip' => '',
    },
    'netgear-wgt624' => {
        'name' => 'Netgear WGT624',
        'url' => '/RST_st_dhcp.htm',
        'skip' => 'IP Address</B></td><TD NOWRAP width="50%">',
    },
    'sveasoft' => {
        'name' => 'Sveasoft WRT54G/WRT54GS',
        'url' => '/Status_Router.asp',
        'skip' => 'var wan_ip',
    },
    'smc-barricade-7004vbr' => {
        'name' => 'SMC Barricade FW (7004VBR model config)',
        'url' => '/status_main.stm',
        'skip' => 'var wan_ip=',
    },
    'sitecom-dc202' => {
        'name' => 'Sitecom DC-202 FW',
        'url' => '/status.htm',
        'skip' => 'Internet IP Address',
    },
);
my %ip_strategies = (
     'ip'                     => ": obtain IP from -ip {address}",
     'web'                    => ": obtain IP from an IP discovery page on the web",
     'fw'                     => ": obtain IP from the firewall specified by -fw {type|address}",
     'if'                     => ": obtain IP from the -if {interface}",
     'cmd'                    => ": obtain IP from the -cmd {external-command}",
     'cisco'                  => ": obtain IP from Cisco FW at the -fw {address}",
     'cisco-asa'              => ": obtain IP from Cisco ASA at the -fw {address}",
     map { $_ => sprintf ": obtain IP from %s at the -fw {address}", $builtinfw{$_}->{'name'} } keys %builtinfw,
);
sub ip_strategies_usage {
    return map { sprintf("    -use=%-22s %s.", $_, $ip_strategies{$_}) } sort keys %ip_strategies;
}

my %web_strategies = (
	'dyndns'=> 1,
	'dnspark'=> 1,
	'loopia'=> 1,
);

sub setv {
    return {
	'type'     => shift,
	'required' => shift,
	'cache'    => shift,
	'config'   => shift,
	'default'  => shift,
	'minimum'  => shift,
    };
};
my %variables = (
    'global-defaults'    => {
	'daemon'              => setv(T_DELAY, 0, 0, 1, 0,                    interval('60s')),
	'foreground'          => setv(T_BOOL,  0, 0, 1, 0,                    undef),
	'file'                => setv(T_FILE,  0, 0, 1, "$etc$program.conf",  undef),
	'cache'               => setv(T_FILE,  0, 0, 1, "$cachedir$program.cache", undef),
	'pid'                 => setv(T_FILE,  0, 0, 1, "",                   undef),
	'proxy'               => setv(T_FQDNP, 0, 0, 1, '',                   undef),
	'protocol'            => setv(T_PROTO, 0, 0, 1, 'dyndns2',            undef),

	'use'                 => setv(T_USE,   0, 0, 1, 'ip',                 undef),
	'ip'                  => setv(T_IP,    0, 0, 1, undef,                undef),
	'if'                  => setv(T_IF,    0, 0, 1, 'ppp0',               undef),
	'if-skip'             => setv(T_STRING,1, 0, 1, '',                   undef),
	'web'                 => setv(T_STRING,0, 0, 1, 'dyndns',             undef),
	'web-skip'            => setv(T_STRING,1, 0, 1, '',                   undef),
	'fw'                  => setv(T_ANY,   0, 0, 1, '', 		      undef),
	'fw-skip'             => setv(T_STRING,1, 0, 1, '',                   undef),
	'fw-login'            => setv(T_LOGIN, 1, 0, 1, '',                   undef),
	'fw-password'         => setv(T_PASSWD,1, 0, 1, '',                   undef),
	'cmd'                 => setv(T_PROG,  0, 0, 1, '',                   undef),
	'cmd-skip'            => setv(T_STRING,1, 0, 1, '',                   undef),

	'timeout'             => setv(T_DELAY, 0, 0, 1, interval('120s'),     interval('120s')),
	'retry'               => setv(T_BOOL,  0, 0, 0, 0,                    undef),
	'force'               => setv(T_BOOL,  0, 0, 0, 0,                    undef),
	'ssl'                 => setv(T_BOOL,  0, 0, 0, 0,                    undef),

	'syslog'              => setv(T_BOOL,  0, 0, 1, 0,                    undef),
	'facility'            => setv(T_STRING,0, 0, 1, 'daemon',             undef),
	'priority'            => setv(T_STRING,0, 0, 1, 'notice',             undef),
        'mail'                => setv(T_EMAIL, 0, 0, 1, '',                   undef),
        'mail-failure'        => setv(T_EMAIL, 0, 0, 1, '',                   undef),

	'exec'                => setv(T_BOOL,  0, 0, 1, 1,                    undef),
	'debug'               => setv(T_BOOL,  0, 0, 1, 0,                    undef),
	'verbose'             => setv(T_BOOL,  0, 0, 1, 0,                    undef),
	'quiet'               => setv(T_BOOL,  0, 0, 1, 0,                    undef),
	'help'                => setv(T_BOOL,  0, 0, 1, 0,                    undef),
	'test'                => setv(T_BOOL,  0, 0, 1, 0,                    undef),
	'geturl'              => setv(T_STRING,0, 0, 0, '',                   undef),

	'postscript'          => setv(T_POSTS, 0, 0, 1, '',                   undef),
    },
    'service-common-defaults'       => {
	'server'	      => setv(T_FQDNP,  1, 0, 1, 'members.dyndns.org', undef),
	'login'               => setv(T_LOGIN,  1, 0, 1, '',                  undef),
	'password'            => setv(T_PASSWD, 1, 0, 1, '',                  undef),
	'host'                => setv(T_STRING, 1, 1, 1, '',                  undef),

	'use'                 => setv(T_USE,   0, 0, 1, 'ip',                 undef),
	'if'                  => setv(T_IF,    0, 0, 1, 'ppp0',               undef),
	'if-skip'             => setv(T_STRING,0, 0, 1, '',                   undef),
	'web'                 => setv(T_STRING,0, 0, 1, 'dyndns',             undef),
	'web-skip'            => setv(T_STRING,0, 0, 1, '',                   undef),
	'fw'                  => setv(T_ANY,   0, 0, 1, '', 		      undef),
	'fw-skip'             => setv(T_STRING,0, 0, 1, '',                   undef),
	'fw-login'            => setv(T_LOGIN, 0, 0, 1, '',                   undef),
	'fw-password'         => setv(T_PASSWD,0, 0, 1, '',                   undef),
	'cmd'                 => setv(T_PROG,  0, 0, 1, '',                   undef),
	'cmd-skip'            => setv(T_STRING,0, 0, 1, '',                   undef),

	'ip'                  => setv(T_IP,     0, 1, 0, undef,               undef),
	'wtime'               => setv(T_DELAY,  0, 1, 1, 0,                   interval('30s')),
	'mtime'               => setv(T_NUMBER, 0, 1, 0, 0,                   undef),
	'atime'               => setv(T_NUMBER, 0, 1, 0, 0,                   undef),
	'status'              => setv(T_ANY,    0, 1, 0, '',                  undef),
	'min-interval'        => setv(T_DELAY,  0, 0, 1, interval('30s'),     0),
	'max-interval'        => setv(T_DELAY,  0, 0, 1, interval('25d'),     0),
	'min-error-interval'  => setv(T_DELAY,  0, 0, 1, interval('5m'),      0),

	'warned-min-interval'       => setv(T_ANY,    0, 1, 0, 0,             undef),
	'warned-min-error-interval' => setv(T_ANY,    0, 1, 0, 0,             undef),
    },
    'dyndns-common-defaults'       => {
	'static'              => setv(T_BOOL,   0, 1, 1, 0,                   undef),
	'wildcard'            => setv(T_BOOL,   0, 1, 1, 0,                   undef),
	'mx'	              => setv(T_OFQDN,  0, 1, 1, '',                  undef),
	'backupmx'            => setv(T_BOOL,   0, 1, 1, 0,                   undef),
    },
    'easydns-common-defaults'       => {
	'wildcard'            => setv(T_BOOL,   0, 1, 1, 0,                   undef),
	'mx'	              => setv(T_OFQDN,  0, 1, 1, '',                  undef),
	'backupmx'            => setv(T_BOOL,   0, 1, 1, 0,                   undef),
    },
    'dnspark-common-defaults'       => {
	'mx'	              => setv(T_OFQDN,  0, 1, 1, '',                  undef),
	'mxpri'               => setv(T_NUMBER, 0, 0, 1, 5,                   undef),
    },
    'noip-common-defaults'       => {
	'static'              => setv(T_BOOL,   0, 1, 1, 0,                   undef),
    },
    'noip-service-common-defaults'       => {
	'server'	      => setv(T_FQDNP,  1, 0, 1, 'dynupdate.no-ip.com', undef),
	'login'               => setv(T_LOGIN,  1, 0, 1, '',                  undef),
	'password'            => setv(T_PASSWD, 1, 0, 1, '',                  undef),
	'host'                => setv(T_STRING, 1, 1, 1, '',                  undef),
	'ip'                  => setv(T_IP,     0, 1, 0, undef,               undef),
	'wtime'               => setv(T_DELAY,  0, 1, 1, 0,                   interval('30s')),
	'mtime'               => setv(T_NUMBER, 0, 1, 0, 0,                   undef),
	'atime'               => setv(T_NUMBER, 0, 1, 0, 0,                   undef),
	'status'              => setv(T_ANY,    0, 1, 0, '',                  undef),
	'min-interval'        => setv(T_DELAY,  0, 0, 1, interval('30s'),     0),
	'max-interval'        => setv(T_DELAY,  0, 0, 1, interval('25d'),     0),
	'min-error-interval'  => setv(T_DELAY,  0, 0, 1, interval('5m'),      0),
	'warned-min-interval'       => setv(T_ANY,    0, 1, 0, 0,             undef),
	'warned-min-error-interval' => setv(T_ANY,    0, 1, 0, 0,             undef),
    },
    'zoneedit-service-common-defaults'       => {
        'zone'                => setv(T_OFQDN,  0, 0, 1, undef,               undef),
    },
    'dtdns-common-defaults'       => {
	'login'               => setv(T_LOGIN,  0, 0, 0, 'unused',            undef),
	'client'              => setv(T_STRING, 0, 1, 1, $program,            undef),
    },
);
my %services = (
    'dyndns1' => {
	'updateable' => \&nic_dyndns2_updateable,
	'update'     => \&nic_dyndns1_update,
	'examples'   => \&nic_dyndns1_examples,
	'variables'  => merge(
			  $variables{'dyndns-common-defaults'},
			  $variables{'service-common-defaults'},
		        ),
    },
    'dyndns2' => {
	'updateable' => \&nic_dyndns2_updateable,
	'update'     => \&nic_dyndns2_update,
	'examples'   => \&nic_dyndns2_examples,
	'variables'  => merge(
			  { 'custom'  => setv(T_BOOL,   0, 1, 1, 0, undef),	},
			  { 'script'  => setv(T_STRING, 1, 1, 1, '/nic/update', undef),	},
#			  { 'offline' => setv(T_BOOL,   0, 1, 1, 0, undef),	},
			  $variables{'dyndns-common-defaults'},
			  $variables{'service-common-defaults'},
		        ),
    },
    'noip' => {
	'updateable' => undef,
	'update'     => \&nic_noip_update,
	'examples'   => \&nic_noip_examples,
	'variables'  => merge(
			  { 'custom'  => setv(T_BOOL,   0, 1, 1, 0, undef),	},
			  $variables{'noip-common-defaults'},
			  $variables{'noip-service-common-defaults'},
		        ),
    },
    'concont' => {
        'updateable' => undef,
        'update'     => \&nic_concont_update,
        'examples'   => \&nic_concont_examples,
        'variables'  => merge(
                          $variables{'service-common-defaults'},
                          { 'mx'       => setv(T_OFQDN,  0, 1, 1, '', undef), },
                          { 'wildcard' => setv(T_BOOL,   0, 1, 1,  0, undef), },
                        ),
    },  
    'dslreports1' => {
	'updateable' => undef,
	'update'     => \&nic_dslreports1_update,
	'examples'   => \&nic_dslreports1_examples,
	'variables'  => merge(
			  { 'host' => setv(T_NUMBER,   1, 1, 1, 0, undef)       },
			  $variables{'service-common-defaults'},
		        ),
    },
    'hammernode1' => {
	'updateable' => undef,
	'update'     => \&nic_hammernode1_update,
	'examples'   => \&nic_hammernode1_examples,
	'variables'  => merge(
			  { 'server'       => setv(T_FQDNP,  1, 0, 1, 'dup.hn.org',   undef)    },
			  { 'min-interval' => setv(T_DELAY,  0, 0, 1, interval('5m'), 0),},
 			  $variables{'service-common-defaults'},
		        ),
    },
    'zoneedit1' => {
	'updateable' => undef,
	'update'     => \&nic_zoneedit1_update,
	'examples'   => \&nic_zoneedit1_examples,
	'variables'  => merge(
			  { 'server'       => setv(T_FQDNP,  1, 0, 1, 'dynamic.zoneedit.com', undef)          },
			  { 'min-interval' => setv(T_DELAY,  0, 0, 1, interval('5m'), 0),},
 			  $variables{'service-common-defaults'},
 			  $variables{'zoneedit-service-common-defaults'},
		        ),
    },
    'easydns' => {
	'updateable' => undef,
	'update'     => \&nic_easydns_update,
	'examples'   => \&nic_easydns_examples,
	'variables'  => merge(
			  { 'server'       => setv(T_FQDNP,  1, 0, 1, 'members.easydns.com', undef)          },
			  { 'min-interval' => setv(T_DELAY,  0, 0, 1, interval('5m'), 0),},
			  $variables{'easydns-common-defaults'},
 			  $variables{'service-common-defaults'},
		        ),
    },
    'dnspark' => {
	'updateable' => undef,
	'update'     => \&nic_dnspark_update,
	'examples'   => \&nic_dnspark_examples,
	'variables'  => merge(
			  { 'server'       => setv(T_FQDNP,  1, 0, 1, 'www.dnspark.com', undef)          },
			  { 'min-interval' => setv(T_DELAY,  0, 0, 1, interval('5m'), 0),},
			  $variables{'dnspark-common-defaults'},
 			  $variables{'service-common-defaults'},
		        ),
    },
    'namecheap' => {
        'updateable' => undef,
        'update'     => \&nic_namecheap_update,
        'examples'   => \&nic_namecheap_examples,
        'variables'  => merge(
                          { 'server'       => setv(T_FQDNP,  1, 0, 1, 'dynamicdns.park-your-domain.com',   undef)    },
                          { 'min-interval' => setv(T_DELAY,  0, 0, 1, 0, interval('5m')),},
                          $variables{'service-common-defaults'},
                        ),
    },
    'sitelutions' => {
        'updateable' => undef,
        'update'     => \&nic_sitelutions_update,
        'examples'   => \&nic_sitelutions_examples,
        'variables'  => merge(
                          { 'server'       => setv(T_FQDNP,  1, 0, 1, 'www.sitelutions.com',   undef)    },
                          { 'min-interval' => setv(T_DELAY,  0, 0, 1, 0, interval('5m')),},
                          $variables{'service-common-defaults'},
                        ),
    },
    'freedns' => {
        'updateable' => undef,
        'update'     => \&nic_freedns_update,
        'examples'   => \&nic_freedns_examples,
        'variables'  => merge(
			  { 'server'       => setv(T_FQDNP,  1, 0, 1, 'freedns.afraid.org',    undef)    },
			  { 'min-interval' => setv(T_DELAY,  0, 0, 1, 0, interval('5m')),},
			  $variables{'service-common-defaults'},
			),
    },
    'changeip' => {
        'updateable' => undef,
        'update'     => \&nic_changeip_update,
        'examples'   => \&nic_changeip_examples,
        'variables'  => merge(
			  { 'server'       => setv(T_FQDNP,  1, 0, 1, 'nic.changeip.com',    undef)    },
			  { 'min-interval' => setv(T_DELAY,  0, 0, 1, 0, interval('5m')),},
			  $variables{'service-common-defaults'},
			),
    },
    'dtdns' => {
	'updateable' => undef,
	'update'     => \&nic_dtdns_update,
	'examples'   => \&nic_dtdns_examples,
	'variables'  => merge(
			  $variables{'dtdns-common-defaults'},
			  $variables{'service-common-defaults'},
		        ),
    },
);
$variables{'merged'} = merge($variables{'global-defaults'},
			     $variables{'service-common-defaults'},
			     $variables{'dyndns-common-defaults'},
			     map { $services{$_}{'variables'} } keys %services,
);

my @opt = (
    "usage: ${program} [options]",
    "options are:",
    [ "daemon",      "=s", "-daemon delay         : run as a daemon, specify delay as an interval." ],
+     [ "foreground",  "!",  "-foreground           : do not fork" ],
    [ "proxy",       "=s", "-proxy host           : use 'host' as the HTTP proxy" ],
    [ "server",      "=s", "-server host          : update DNS information on 'host'" ],
    [ "protocol",    "=s", "-protocol type        : update protocol used" ],
    [ "file",        "=s", "-file path            : load configuration information from 'path'" ],
    [ "cache",       "=s", "-cache path           : record address used in 'path'" ],
    [ "pid",         "=s", "-pid path             : record process id in 'path'" ],
    "",			     
    [ "use",         "=s", "-use which            : how the should IP address be obtained." ],
                                                  &ip_strategies_usage(),
    "",			     
    [ "ip",          "=s", "-ip address           : set the IP address to 'address'" ],
    "",			     
    [ "if",          "=s", "-if interface         : obtain IP address from 'interface'" ],
    [ "if-skip",     "=s", "-if-skip pattern      : skip any IP addresses before 'pattern' in the output of ifconfig {if}" ],
    "",
    [ "web",         "=s", "-web provider|url     : obtain IP address from provider's IP checking page" ],
    [ "web-skip",    "=s", "-web-skip pattern     : skip any IP addresses before 'pattern' on the web provider|url" ],
    "",
    [ "fw",          "=s", "-fw address|url       : obtain IP address from firewall at 'address'" ],
    [ "fw-skip",     "=s", "-fw-skip pattern      : skip any IP addresses before 'pattern' on the firewall address|url" ],
    [ "fw-login",    "=s", "-fw-login login       :   use 'login' when getting IP from fw" ],
    [ "fw-password", "=s", "-fw-password secret   :   use password 'secret' when getting IP from fw" ],
    "",			     
    [ "cmd",         "=s", "-cmd program          : obtain IP address from by calling {program}" ],
    [ "cmd-skip",    "=s", "-cmd-skip pattern     : skip any IP addresses before 'pattern' in the output of {cmd}" ],
    "",			     
    [ "login",       "=s", "-login user           : login as 'user'" ],
    [ "password",    "=s", "-password secret      : use password 'secret'" ],
    [ "host",        "=s", "-host host            : update DNS information for 'host'" ],
    "",			     
    [ "options",     "=s",  "-options opt,opt     : optional per-service arguments (see below)" ],
    "",			     
    [ "ssl",         "!",  "-{no}ssl              : do updates over encrypted SSL connection" ],
    [ "retry",       "!",  "-{no}retry            : retry failed updates." ],
    [ "force",       "!",  "-{no}force            : force an update even if the update may be unnecessary" ],
    [ "timeout",     "=i", "-timeout max          : wait at most 'max' seconds for the host to respond" ],

    [ "syslog",      "!",  "-{no}syslog           : log messages to syslog" ],
    [ "facility",    "=s", "-facility {type}      : log messages to syslog to facility {type}" ],
    [ "priority",    "=s", "-priority {pri}       : log messages to syslog with priority {pri}" ],
    [ "mail",        "=s", "-mail address         : e-mail messages to {address}" ],
    [ "mail-failure","=s", "-mail-failure address : e-mail messages for failed updates to {address}" ],
    [ "exec",        "!",  "-{no}exec             : do {not} execute; just show what would be done" ],
    [ "debug",       "!",  "-{no}debug            : print {no} debugging information" ],
    [ "verbose",     "!",  "-{no}verbose          : print {no} verbose information" ],
    [ "quiet",       "!",  "-{no}quiet            : print {no} messages for unnecessary updates" ],
    [ "help",        "",   "-help                 : this message" ],
    [ "postscript",  "",   "-postscript           : script to run after updating ddclient, has new IP as param" ],

    [ "query",       "!",  "-{no}query            : print {no} ip addresses and exit" ],
    [ "test",        "!",  "" ], ## hidden
    [ "geturl",      "=s", "" ], ## hidden
    "",
    nic_examples(),
    "$program version $version, ",
    "  originally written by Paul Burry, paul+ddclient\@burry.ca",
    "  project now maintained on http://ddclient.sourceforge.net"
);

## process args
my ($opt_usage, %opt) = process_args(@opt);
my ($result, %config, %globals, %cache);
my $saved_cache = '';
my %saved_opt = %opt;
$result = 'OK';

test_geturl(opt('geturl')) if opt('geturl');

## process help option
if (opt('help')) {
    *STDERR = *STDOUT;
    usage(0);
}

## read config file because 'daemon' mode may be defined there.
read_config(define($opt{'file'}, default('file')), \%config, \%globals);
init_config();
test_possible_ip()         if opt('query');

if (!opt('daemon') && $programd =~ /d$/) {
    $opt{'daemon'} = minimum('daemon');
}
my $caught_hup  = 0;
my $caught_term = 0;
my $caught_kill = 0;
$SIG{'HUP'}    = sub { $caught_hup  = 1; };
$SIG{'TERM'}   = sub { $caught_term = 1; };
$SIG{'KILL'}   = sub { $caught_kill = 1; };
# don't fork() if foreground or force is on
if (opt('foreground') || opt('force')) {
    ;
} elsif (opt('daemon')) {
    $SIG{'CHLD'}   = 'IGNORE';
    my $pid = fork;
    if ($pid < 0) {
	print STDERR "${program}: can not fork ($!)\n";
	exit -1;
    } elsif ($pid) {
	exit 0;
    }
    $SIG{'CHLD'}   = 'DEFAULT';
    open(STDOUT, ">/dev/null");
    open(STDERR, ">/dev/null");
    open(STDIN,  "</dev/null");
}

# write out the pid file if we're daemon'ized
if(opt('daemon')) { 
    write_pid();
    $opt{'syslog'} = 1;
}

umask 077;
my $daemon;
do {
    $now = time;
    $result = 'OK';
    %opt = %saved_opt;
    if (opt('help')) {
            *STDERR = *STDOUT;
    		printf("Help found");
	           # usage();
		        }

    read_config(define($opt{'file'}, default('file')), \%config, \%globals);
    init_config();
    read_cache(opt('cache'), \%cache);
    print_info() if opt('debug') && opt('verbose');

#   usage("invalid argument '-use %s'; possible values are:\n\t%s", $opt{'use'}, join("\n\t,",sort keys %ip_strategies))
    usage("invalid argument '-use %s'; possible values are:\n%s", $opt{'use'}, join("\n",ip_strategies_usage()))
      unless exists $ip_strategies{lc opt('use')};
    
    $daemon = $opt{'daemon'};
    $daemon = 0 if opt('force');

    update_nics();

    if ($daemon) {
	debug("sleep %s",  $daemon);
	sendmail();

	my $left = $daemon;
	while (($left > 0) && !$caught_hup && !$caught_term && !$caught_kill) {
		my $delay = $left > 10 ? 10 : $left;

		$0 = sprintf("%s - sleeping for %s seconds", $program, $left);
        	$left -= sleep $delay;
		# preventing deep sleep - see [bugs:#46]
		if ($left > $daemon) {
			$left = $daemon;
		}
	}
	$caught_hup = 0;
	$result = 0;

    } elsif (! scalar(%config)) {
	warning("no hosts to update.") unless !opt('quiet') || opt('verbose') || !$daemon;
	$result = 1;

    } else {
	$result = $result eq 'OK' ? 0 : 1;
    }
} while ($daemon && !$result && !$caught_term && !$caught_kill);

warning("caught SIGKILL; exiting") if $caught_kill;
unlink_pid();
sendmail();

exit($result);

######################################################################
## runpostscript
######################################################################

sub runpostscript {
	my ($ip) = @_;

	if ( defined $globals{postscript} ) {
		if ( -x $globals{postscript}) {
			system ("$globals{postscript} $ip &");
		} else {
			warning ("Can not execute post script: %s", $globals{postscript}); 
		}
	}
} 

######################################################################
## update_nics
######################################################################
sub update_nics {
	my %examined = ();
	my %iplist = ();

	foreach my $s (sort keys %services) {
		my (@hosts, %ips) = ();
		my $updateable = $services{$s}{'updateable'};
		my $update     = $services{$s}{'update'};

		foreach my $h (sort keys %config) {
			next if $config{$h}{'protocol'} ne lc($s);
			$examined{$h} = 1;
			# we only do this once per 'use' and argument combination
			my $use = opt('use', $h);
			my $arg_ip = opt('ip', $h) || '';
			my $arg_fw = opt('fw', $h) || '';
			my $arg_if = opt('if', $h) || '';
			my $arg_web = opt('web', $h) || '';
			my $arg_cmd = opt('cmd', $h) || '';
			my $ip = "";
			if (exists $iplist{$use}{$arg_ip}{$arg_fw}{$arg_if}{$arg_web}{$arg_cmd}) {
				$ip = $iplist{$use}{$arg_ip}{$arg_fw}{$arg_if}{$arg_web}{$arg_cmd};
			} else {
				$ip = get_ip($use, $h);
				if (!defined $ip || !$ip) {
					warning("unable to determine IP address")
						if !$daemon || opt('verbose');
					next;
				}
				if ($ip !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) {
					warning("malformed IP address (%s)", $ip);
					next;
				}
				$iplist{$use}{$arg_ip}{$arg_fw}{$arg_if}{$arg_web}{$arg_cmd} = $ip;
			}
			$config{$h}{'wantip'} = $ip;
			next if !nic_updateable($h, $updateable);
			push @hosts, $h;
			$ips{$ip} = $h;
		}
		if (@hosts) {
			$0 = sprintf("%s - updating %s", $program, join(',', @hosts));
			&$update(@hosts);
			runpostscript(join ' ', keys %ips);
		}
	}
	foreach my $h (sort keys %config) {
		if (!exists $examined{$h}) {
			failed("%s was not updated because protocol %s is not supported.", 
					$h, define($config{$h}{'protocol'}, '<undefined>')
				  );
		}
	}
	write_cache(opt('cache'));
}
######################################################################
## unlink_pid()
######################################################################
sub unlink_pid {
    if (opt('pid') && opt('daemon')) {	
	unlink opt('pid');
    }
}

######################################################################
## write_pid()
######################################################################
sub write_pid {
    my $file = opt('pid');

    if ($file && opt('daemon')) {	
        local *FD;
	if (! open(FD, "> $file")) {
	    warning("Cannot create file '%s'. ($!)", $file);

    	} else {
       	    printf FD "$$\n";
	    close(FD);
	}
    }
}

######################################################################
## write_cache($file)
######################################################################
sub write_cache {
    my ($file) = @_;

    ## merge the updated host entries into the cache.
    foreach my $h (keys %config) {
	if (! exists $cache{$h} || $config{$h}{'update'}) {
	    map {$cache{$h}{$_} = $config{$h}{$_} } @{$config{$h}{'cacheable'}};

	} else {
	    map {$cache{$h}{$_} = $config{$h}{$_} } qw(atime wtime status);
	}
    }

    ## construct the cache file.
    my $cache = "";
    foreach my $h (sort keys %cache) {
    	my $opt = join(',', map { "$_=".define($cache{$h}{$_},'') } sort keys %{$cache{$h}});
	    
        $cache .= sprintf "%s%s%s\n", $opt, ($opt ? ' ' : ''), $h;
    }
    $file = '' if defined($saved_cache) && $cache eq $saved_cache;

    ## write the updates and other entries to the cache file.
    if ($file) {
	$saved_cache = undef;
	local *FD;
	if (! open(FD, "> $file")) {
	    fatal("Cannot create file '%s'. ($!)", $file);
	}
	printf FD "## $program-$version\n";
	printf FD "## last updated at %s (%d)\n", prettytime($now), $now;
	printf FD $cache;

	close(FD);
    }
}
######################################################################
## read_cache($file) - called before reading the .conf
######################################################################
sub read_cache {
    my $file    = shift;
    my $config  = shift;
    my $globals = {};

    %{$config} = ();
    ## read the cache file ignoring anything on the command-line.
    if (-e $file) {
	my %saved = %opt;
	%opt   = ();
	$saved_cache = _read_config($config, $globals, "##\\s*$program-$version\\s*", $file);
	%opt   = %saved;

	foreach my $h (keys %cache) {
	    if (exists $config->{$h}) {
		foreach (qw(atime mtime wtime ip status)) {
	    	    $config->{$h}{$_} = $cache{$h}{$_} if exists $cache{$h}{$_};
		}
	    }
	}
    }
}
######################################################################
## parse_assignments(string) return (rest, %variables)
## parse_assignment(string)  return (name, value, rest)
######################################################################
sub parse_assignments {
    my $rest = shift;
    my @args = @_;
    my %variables = ();
    my ($name, $value);

    while (1) {
	$rest =~ s/^\s+//;
        ($name, $value, $rest) = parse_assignment($rest, @args);
	if (defined $name) {
	    $variables{$name} = $value;
	} else {
	    last;
	}
    }
    return ($rest, %variables);
}
sub parse_assignment {
    my $rest   = shift;
    my $stop   = @_ ? shift : '[\n\s,]';
    my ($c, $name, $value);
    my ($escape, $quote) = (0, '');

    if ($rest =~ /^\s*([a-z][a-z_-]*)=(.*)/i) {
	($name, $rest, $value) = ($1, $2, '');

	while (length($c = substr($rest,0,1))) {
	    $rest = substr($rest,1);
	    if ($escape) {
		$value .= $c;
		$escape = 0;
	    } elsif ($c eq "\\") {
		$escape = 1;
	    } elsif ($quote && $c eq $quote) {
		$quote = ''
	    } elsif (!$quote && $c =~ /[\'\"]/) {
		$quote = $c;
	    } elsif (!$quote && $c =~ /^${stop}/) {
		last;
	    } else {
		$value .= $c;
	    }
	}
    }
    warning("assignment ended with an open quote") if $quote;
    return ($name, $value, $rest);
}
######################################################################
## read_config
######################################################################
sub read_config {
    my $file       = shift;
    my $config     = shift;
    my $globals    = shift;
    my %globals    = ();

    _read_config($config, $globals, '', $file, %globals);
}
sub _read_config {
    my $config  = shift;
    my $globals = shift;
    my $stamp   = shift;
    local $file = shift;
    my %globals = @_;
    my %config  = ();
    my $content = '';

    local *FD;
    if (! open(FD, "< $file")) {
	# fatal("Cannot open file '%s'. ($!)", $file);
	warning("Cannot open file '%s'. ($!)", $file);
    }
    # Check for only owner has any access to config file
    my ($dev, $ino, $mode, @statrest) = stat(FD);
    if ($mode & 077) {                          
	if (-f FD && (chmod 0600, $file)) {
	    warning("file $file must be accessible only by its owner (fixed).");
	} else {
	    # fatal("file $file must be accessible only by its owner.");
	    warning("file $file must be accessible only by its owner.");
	}
    }

    local $lineno       = 0;
    my    $continuation = '';
    my    %passwords    = ();
    while (<FD>) {
	s/[\r\n]//g;

	$lineno++;

	## check for the program version stamp
	if (($. == 1) && $stamp && ($_ !~ /^$stamp$/i)) {
	    warning("program version mismatch; ignoring %s", $file);
	    last;
	}
    if (/\\\s+$/) {
	    warning("whitespace follows the \\ at the end-of-line.\nIf you meant to have a line continuation, remove the trailing whitespace.");
    }

    $content .= "$_\n" unless /^#/;

	## parsing passwords is special
	if (/^([^#]*\s)?([^#]*?password\S*?)\s*=\s*('.*'|[^']\S*)(.*)/) {
	    my ($head, $key, $value, $tail) = ($1 || '', $2, $3, $4);
	    $value = $1 if $value =~ /^'(.*)'$/;
	    $passwords{$key} = $value;
	    $_ = "${head}${key}=dummy${tail}";
	}

        ## remove comments
	s/#.*//;

	## handle continuation lines
	$_ = "$continuation$_";
	if (/\\$/) {
	    chop;
	    $continuation = $_;
	    next;
	}
	$continuation = '';

	s/^\s+//;		# remove leading white space
	s/\s+$//;		# remove trailing white space
	s/\s+/ /g;		# canonify
	next if /^$/;

	## expected configuration line is:
	##   [opt=value,opt=..] [host [login [password]]]
	my %locals;
	($_, %locals) = parse_assignments($_);
	s/\s*,\s*/,/g;
	my @args = split;
	
	## verify that keywords are valid...and check the value
	foreach my $k (keys %locals) {
	    $locals{$k} = $passwords{$k} if defined $passwords{$k};
	    if (!exists $variables{'merged'}{$k}) {
            warning("unrecognized keyword '%s' (ignored)", $k);
            delete $locals{$k};
	    } else {
            my $def = $variables{'merged'}{$k};
            my $value = check_value($locals{$k}, $def);
            if (!defined($value)) {
                warning("Invalid Value for keyword '%s' = '%s'", $k, $locals{$k});
                delete $locals{$k};
            } else { $locals{$k} = $value; }
        }
	}
	if (exists($locals{'host'})) {
	    $args[0] = @args ? "$args[0],$locals{host}" : "$locals{host}";
	}
	## accumulate globals
	if ($#args < 0) {
	    map { $globals{$_} = $locals{$_} } keys %locals;
	}
	
	## process this host definition
	if (@args) {
	    my ($host, $login, $password) = @args;
	    
	    ## add in any globals..
	    %locals = %{ merge(\%locals, \%globals) };
	    
	    ## override login and password if specified the old way.
	    $locals{'login'}    = $login    if defined $login;
	    $locals{'password'} = $password if defined $password;
	    
	    ## allow {host} to be a comma separated list of hosts 
	    foreach my $h (split_by_comma($host)) {
		## save a copy of the current globals
		$config{$h}         = { %locals };
		$config{$h}{'host'} = $h;
	    }
	}
	%passwords = ();
    }
    close(FD);
    
    warning("file ends while expecting a continuation line.")
      if $continuation;

    %$globals = %globals;
    %$config  = %config;

    return $content;
}
######################################################################
## init_config - 
######################################################################
sub init_config {
    %opt = %saved_opt;

    ## 
    $opt{'quiet'}   = 0 if   opt('verbose');

    ## infer the IP strategy if possible
    $opt{'use'} = 'ip'  if !define($opt{'use'}) && defined($opt{'ip'});
    $opt{'use'} = 'if'  if !define($opt{'use'}) && defined($opt{'if'});
    $opt{'use'} = 'web' if !define($opt{'use'}) && defined($opt{'web'});

    ## sanity check
    $opt{'max-interval'}       = min(interval(opt('max-interval')), interval(default('max-interval')));
    $opt{'min-interval'}       = max(interval(opt('min-interval')), interval(default('min-interval')));
    $opt{'min-error-interval'} = max(interval(opt('min-error-interval')), interval(default('min-error-interval')));

    $opt{'timeout'}  = 0               if opt('timeout') < 0;

    ## only set $opt{'daemon'} if it has been explicitly passed in
    if (define($opt{'daemon'},$globals{'daemon'},0)) {
        $opt{'daemon'} = interval(opt('daemon'));
        $opt{'daemon'} = minimum('daemon')
          if ($opt{'daemon'} < minimum('daemon'));
    }
    
    ## define or modify host options specified on the command-line
    if (exists $opt{'options'} && defined $opt{'options'}) {
	## collect cmdline configuration options.
	my %options = ();
	foreach my $opt (split_by_comma($opt{'options'})) {
	    my ($name,$var) = split /\s*=\s*/, $opt;
	    $options{$name} = $var;
	}
	## determine hosts specified with -host
	my @hosts = ();
	if (exists  $opt{'host'}) {
	    foreach my $h (split_by_comma($opt{'host'})) {
		push @hosts, $h;
	    }
	}
	## and those in -options=...
	if (exists  $options{'host'}) {
	    foreach my $h (split_by_comma($options{'host'})) {
		push @hosts, $h;
	    }
	    delete $options{'host'};
	}
	## merge options into host definitions or globals
	if (@hosts) {
	    foreach my $h (@hosts) {
		$config{$h} = merge(\%options, $config{$h});
	    }
	    $opt{'host'} = join(',', @hosts);
	} else {
	    %globals = %{ merge(\%options, \%globals) };
	}
    }

    ## override global options with those on the command-line.
    foreach my $o (keys %opt) {
	if (defined $opt{$o} && exists $variables{'global-defaults'}{$o}) {
	    $globals{$o} = $opt{$o};
	}
    }

    ## sanity check
    if (defined $opt{'host'} && defined $opt{'retry'}) {
	usage("options -retry and -host (or -option host=..) are mutually exclusive");
    }

    ## determine hosts to update (those on the cmd-line, config-file, or failed cached)
    my @hosts = keys %config;
    if (opt('host')) {
	@hosts = split_by_comma($opt{'host'});
    }
    if (opt('retry')) {
	@hosts = map { $_ if $cache{$_}{'status'} ne 'good' } keys %cache;
    }

    ## remove any other hosts 
    my %hosts;
    map { $hosts{$_} = undef } @hosts;
    map { delete $config{$_} unless exists $hosts{$_} } keys %config;

    ## collect the cacheable variables.
    foreach my $proto (keys %services) {
	my @cacheable = ();
	foreach my $k (keys %{$services{$proto}{'variables'}}) {
	    push @cacheable, $k if $services{$proto}{'variables'}{$k}{'cache'};
	}
	$services{$proto}{'cacheable'} = [ @cacheable ];
    }

    ## sanity check..
    ## make sure config entries have all defaults and they meet minimums
    ## first the globals...
    foreach my $k (keys %globals) {
	my $def    = $variables{'merged'}{$k};
	my $ovalue = define($globals{$k}, $def->{'default'});
	my $value  = check_value($ovalue, $def);
	if ($def->{'required'} && !defined $value) {
	    $value = default($k);
	    warning("'%s=%s' is an invalid %s. (using default of %s)", $k, $ovalue, $def->{'type'}, $value);
	}
	$globals{$k} = $value;
    }

    ## now the host definitions...
  HOST:
    foreach my $h (keys %config) {
	my $proto;
	$proto = $config{$h}{'protocol'};
	$proto = opt('protocol')          if !defined($proto);

	load_sha1_support() if ($proto eq "freedns");

 	if (!exists($services{$proto})) {
	    warning("skipping host: %s: unrecognized protocol '%s'", $h, $proto);
	    delete $config{$h};

	} else {
	    my $svars    = $services{$proto}{'variables'};
	    my $conf     = { 'protocol' => $proto };

	    foreach my $k (keys %$svars) {
		my $def    = $svars->{$k};
		my $ovalue = define($config{$h}{$k}, $def->{'default'});
		my $value  = check_value($ovalue, $def);
		if ($def->{'required'} && !defined $value) {
		    warning("skipping host: %s: '%s=%s' is an invalid %s.", $h, $k, $ovalue, $def->{'type'});
		    delete $config{$h};
		    next HOST;
		}
		$conf->{$k} = $value;

	    }
	    $config{$h} = $conf;
	    $config{$h}{'cacheable'} = [ @{$services{$proto}{'cacheable'}} ];
	}
    }
}

######################################################################
## usage
######################################################################
sub usage {
    my $exitcode = 1;
    $exitcode = shift if @_ != 0; # use first arg if given
    my $msg = '';
    if (@_) {
	my $format = shift;
	$msg .= sprintf $format, @_;
	1 while chomp($msg);
    	$msg .= "\n";
    }
    printf STDERR "%s%s\n", $msg, $opt_usage;
    sendmail();
    exit $exitcode;
}

######################################################################
## process_args - 
######################################################################
sub process_args {
    my @spec  = ();
    my $usage = "";
    my %opts  = ();
    
    foreach (@_) {
	if (ref $_) {
	    my ($key, $specifier, $arg_usage) = @$_;
	    my $value = default($key);
	    
	    ## add a option specifier
	    push @spec, $key . $specifier;
	    
	    ## define the default value which can be overwritten later
	    $opt{$key} = undef;
	    
	    next unless $arg_usage;

	    ## add a line to the usage;
	    $usage .= "  $arg_usage";
	    if (defined($value) && $value ne '') {
		$usage .= " (default: ";
		if ($specifier eq '!') {
		    $usage .= "no" if ($specifier eq '!') && !$value;
		    $usage .= $key;
		} else {
		    $usage .= $value;
		}
		$usage .= ")";
	    }
	    $usage .= ".";
	} else {
	    $usage .= $_;
	}
	$usage .= "\n";
    }
    ## process the arguments
    if (! GetOptions(\%opt, @spec)) {
	$opt{"help"} = 1;
    }
    return ($usage, %opt);
}
######################################################################
## test_possible_ip - print possible IPs
######################################################################
sub test_possible_ip {
    local $opt{'debug'} = 0;

    printf "use=ip, ip=%s address is %s\n", opt('ip'), define(get_ip('ip'), 'NOT FOUND')
	if defined opt('ip');

    {
	local $opt{'use'} = 'if';
	foreach my $if (grep {/^[a-zA-Z]/} `ifconfig -a`) {
	    $if =~ s/:?\s.*//is;
	    local $opt{'if'} = $if;
	    printf "use=if, if=%s address is %s\n", opt('if'), define(get_ip('if'), 'NOT FOUND');
	}
    }
    if (opt('fw')) {
	if (opt('fw') !~ m%/%) {
	    foreach my $fw (sort keys %builtinfw) {
	    	local $opt{'use'} = $fw;
	    	printf "use=$fw address is %s\n", define(get_ip($fw), 'NOT FOUND');
	    }
	}
	local $opt{'use'} = 'fw';
	printf "use=fw, fw=%s address is %s\n", opt('fw'), define(get_ip(opt('fw')), 'NOT FOUND')
	    if ! exists $builtinfw{opt('fw')};
	
    }
    {
	local $opt{'use'} = 'web';
	foreach my $web (sort keys %builtinweb) {
	    local $opt{'web'} = $web;
	    printf "use=web, web=$web address is %s\n", define(get_ip('web'), 'NOT FOUND');
	}
	printf "use=web, web=%s address is %s\n", opt('web'), define(get_ip('web'), 'NOT FOUND')
	    if ! exists $builtinweb{opt('web')};
    }
    if (opt('cmd')) {
	local $opt{'use'} = 'cmd';
	printf "use=cmd, cmd=%s address is %s\n", opt('cmd'), define(get_ip('cmd'), 'NOT FOUND');
    }
    exit 0 unless opt('debug');
}
######################################################################
## test_geturl - print (and save if -test) result of fetching a URL
######################################################################
sub test_geturl {
    my $url = shift;

    my $reply = geturl(opt('proxy'), $url, opt('login'), opt('password'));
    print "URL $url\n";;
    print defined($reply) ? $reply : "<undefined>\n";
    exit;
}
######################################################################
## load_file
######################################################################
sub load_file {
    my $file   = shift;
    my $buffer = '';

    if (exists($ENV{'TEST_CASE'})) {
	my $try = "$file-$ENV{'TEST_CASE'}";
	$file = $try if -f $try;
    }

    local *FD;
    if (open(FD, "< $file")) {
	read(FD, $buffer, -s FD);
	close(FD);
	debug("Loaded %d bytes from %s", length($buffer), $file);
    } else {
	debug("Load failed from %s ($!)", $file);
    }
    return $buffer
}
######################################################################
## save_file
######################################################################
sub save_file {
    my ($file, $buffer, $opt) = @_;

    $file .= "-$ENV{'TEST_CASE'}" if exists $ENV{'TEST_CASE'};
    if (defined $opt) {
	my $i = 0;
	while (-f "$file-$i") {
	    if ('unique' =~ /^$opt/i) {
		my $a = join('\n', grep {!/^Date:/} split /\n/, $buffer);
		my $b = join('\n', grep {!/^Date:/} split /\n/, load_file("$file-$i"));
		last if $a eq $b;
	    }
	    $i++;
	}
	$file = "$file-$i";
    }
    debug("Saving to %s", $file);
    local *FD;
    open(FD, "> $file") or return;
    print FD $buffer;
    close(FD);
    return $buffer;
}
######################################################################
## print_opt
## print_globals
## print_config
## print_cache
## print_info
######################################################################
sub _print_hash {
    my ($string, $ptr) = @_;
    my $value = $ptr;

    if (! defined($ptr)) {
        $value = "<undefined>";
    } elsif (ref $ptr eq 'HASH') {
	foreach my $key (sort keys %$ptr) {
	    _print_hash("${string}\{$key\}", $ptr->{$key});
	}
	return;
    }
    printf "%-36s : %s\n", $string, $value;
}
sub print_hash {
    my ($string, $hash) = @_;
    printf "=== %s ====\n", $string;
    _print_hash($string, $hash);
}
sub print_opt     { print_hash("opt",     \%opt);     }
sub print_globals { print_hash("globals", \%globals); }
sub print_config  { print_hash("config",  \%config);  }
sub print_cache   { print_hash("cache",   \%cache);   }
sub print_info {
    print_opt();
    print_globals();
    print_config();
    print_cache();
}
######################################################################
## pipecmd	- run an external command
## logger
## sendmail
######################################################################
sub pipecmd {
    my $cmd   = shift;
    my $stdin = join("\n", @_);
    my $ok    = 0;

    ## remove trailing newlines
    1 while chomp($stdin);

    ## override when debugging.
    $cmd = opt('exec') ? "| $cmd" : "> /dev/null";

    ## execute the command.
    local *FD;
    if (! open(FD, $cmd)) {
	printf STDERR "$program: cannot execute command %s.\n", $cmd;

    } elsif ($stdin && (! print FD "$stdin\n")) {
	printf STDERR "$program: failed writting to %s.\n", $cmd;
	close(FD);

    } elsif (! close(FD)) {
	printf STDERR "$program: failed closing %s.($@)\n", $cmd;

    } elsif (opt('exec') && $?) {
	printf STDERR "$program: failed %s. ($@)\n", $cmd;

    } else {
	$ok = 1;
    }
    return $ok;
}
sub logger {
    if (opt('syslog') && opt('facility') &&  opt('priority')) { 
	my $facility = opt('facility');
	my $priority = opt('priority');
    	return pipecmd("logger -p$facility.$priority -t${program}\[$$\]", @_);
    }
    return 1;
}
sub sendmail {
    my $recipients = opt('mail');

    if (opt('mail-failure') && ($result ne 'OK' && $result ne '0')) {
	$recipients = opt('mail-failure');
    }
    if ($msgs && $recipients && $msgs ne $last_msgs) {
	pipecmd("sendmail -oi $recipients",
		"To: $recipients",
		"Subject: status report from $program\@$hostname",
		"\r\n",
		$msgs,
		"",
		"regards,",
		"   $program\@$hostname (version $version)"
	);
    }
    $last_msgs = $msgs;
    $msgs      = '';
}
######################################################################
##  split_by_comma		
##  merge
##  default    
##  minimum    
##  opt		
######################################################################
sub split_by_comma {
    my $string = shift;

    return split /\s*[, ]\s*/, $string if defined $string;
    return ();
}
sub merge {
    my %merged = ();
    foreach my $h (@_) {
	foreach my $k (keys %$h) {
	    $merged{$k} = $h->{$k} unless exists $merged{$k};
	}
    }
    return \%merged;
}
sub default      {
    my $v = shift;
    return $variables{'merged'}{$v}{'default'};
}
sub minimum      {
    my $v = shift;
    return $variables{'merged'}{$v}{'minimum'};
}
sub opt {
    my $v = shift;
    my $h = shift;
    return $config{$h}{$v}   if defined($h && $config{$h}{$v});
    return $opt{$v} 	if defined $opt{$v};
    return $globals{$v}	if defined $globals{$v};
    return default($v)  if defined default($v);
    return undef;
}
sub min {
    my $min = shift;
    foreach my $arg (@_) {
	$min = $arg if $arg < $min;
    }
    return $min;
}
sub max {
    my $max = shift;
    foreach my $arg (@_) {
	$max = $arg if $arg > $max;
    }
    return $max;
}
######################################################################
## define
######################################################################
sub define {
    foreach (@_) {
	return $_ if defined $_;
    }
    return undef;
}
######################################################################
## ynu
######################################################################
sub ynu {
    my ($value, $yes, $no, $undef) = @_;

    return $no  if !defined($value) || !$value;
    return $yes if $value eq '1';
    foreach (qw(yes true)) {
	return $yes if $_ =~ /^$value/i;
    }
    foreach (qw(no false)) {
	return $no if $_ =~ /^$value/i;
    }
    return $undef;
}
######################################################################
## msg
## debug
## warning
## fatal
######################################################################
sub _msg {
    my $log    = shift;
    my $prefix = shift;
    my $format = shift;
    my $buffer = sprintf $format, @_;
    chomp($buffer);

    $prefix = sprintf "%-9s ", $prefix if $prefix;
    if ($file) {
	$prefix .= "file $file";
	$prefix .= ", line $lineno" if $lineno;
	$prefix .= ": ";
    }
    if ($prefix) {
	$buffer = "$prefix$buffer";
    	$buffer =~ s/\n/\n$prefix /g;
    }
    $buffer .= "\n";
    print $buffer;

    $msgs .= $buffer  if $log;
    logger($buffer)   if $log;

}
sub msg     { _msg(0, '',         @_);   	      			}
sub verbose { _msg(1, @_)             if opt('verbose');		}
sub info    { _msg(1, 'INFO:',    @_) if opt('verbose');	        }
sub debug   { _msg(0, 'DEBUG:',   @_) if opt('debug');	                }
sub debug2  { _msg(0, 'DEBUG:',   @_) if opt('debug') && opt('verbose');}
sub warning { _msg(1, 'WARNING:', @_);			                }
sub fatal   { _msg(1, 'FATAL:',   @_); sendmail(); exit(1);	        }
sub success { _msg(1, 'SUCCESS:', @_);			                }
sub failed  { _msg(1, 'FAILED:',  @_); $result = 'FAILED';	        }
sub prettytime   { return scalar(localtime(shift));   }

sub prettyinterval {
    my $interval = shift;
    use integer;
    my $s = $interval % 60; $interval /= 60;
    my $m = $interval % 60; $interval /= 60;
    my $h = $interval % 24; $interval /= 24;
    my $d = $interval;
    
    my $string = "";
    $string .= "$d day"    if $d;
    $string .= "s"         if $d > 1;
    $string .= ", "        if $string && $h;
    $string .= "$h hour"   if $h;
    $string .= "s"         if $h > 1;
    $string .= ", "        if $string && $m;
    $string .= "$m minute" if $m;
    $string .= "s"         if $m > 1;
    $string .= ", "        if $string && $s;
    $string .= "$s second" if $s;
    $string .= "s"         if $s > 1;
    return $string;
}
sub interval {
    my $value = shift;
    if ($value =~ /^(\d+)(seconds|s)/i) {
	$value = $1;
    } elsif ($value =~ /^(\d+)(minutes|m)/i) {
	$value = $1 * 60;
    } elsif ($value =~ /^(\d+)(hours|h)/i) {
	$value = $1 * 60*60;
    } elsif ($value =~ /^(\d+)(days|d)/i) {
	$value = $1 * 60*60*24;
    } elsif ($value !~ /^\d+$/) {
	$value = undef;
    }
    return $value;
}
sub interval_expired {
    my ($host, $time, $interval) = @_;

    return 1 if !exists $cache{$host};
    return 1 if !exists $cache{$host}{$time}      || !$cache{$host}{$time};
    return 1 if !exists $config{$host}{$interval} || !$config{$host}{$interval};

    return $now > ($cache{$host}{$time} + $config{$host}{$interval});
}



######################################################################
## check_value
######################################################################
sub check_value {
    my ($value, $def) = @_;
    my $type     = $def->{'type'};
    my $min      = $def->{'minimum'};
    my $required = $def->{'required'};

    if (!defined $value && !$required) {
	;

    } elsif ($type eq T_DELAY) {
	$value = interval($value);
	$value = $min if defined($value) && defined($min) && $value < $min;

    } elsif ($type eq T_NUMBER) {
	return undef if $value !~ /^\d+$/;
	$value = $min if defined($min) && $value < $min;

    } elsif ($type eq T_BOOL) {
	if ($value =~ /^y(es)?$|^t(true)?$|^1$/i) {
	    $value = 1;
	} elsif ($value =~ /^n(o)?$|^f(alse)?$|^0$/i) {
	    $value = 0;
	} else {
	    return undef;
	}
    } elsif ($type eq T_FQDN || $type eq T_OFQDN && $value ne '') {
	$value = lc $value;
	return undef if $value !~ /[^.]\.[^.]/;

    } elsif ($type eq T_FQDNP) {
	$value = lc $value;
	return undef if $value !~ /[^.]\.[^.].*(:\d+)?$/;

    } elsif ($type eq T_PROTO) {
	$value = lc $value;
	return undef if ! exists $services{$value};

    } elsif ($type eq T_USE) {
	$value = lc $value;
	return undef if ! exists $ip_strategies{$value};

    } elsif ($type eq T_FILE) {
	return undef if $value eq "";

    } elsif ($type eq T_IF) {
	return undef if $value !~ /^[a-z0-9:._-]+$/;

    } elsif ($type eq T_PROG) {
	return undef if $value eq "";

    } elsif ($type eq T_LOGIN) {
	return undef if $value eq "";

#    } elsif ($type eq T_PASSWD) {
#	return undef if $value =~ /:/;

    } elsif ($type eq T_IP) {
	return undef if $value !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
    }
    return $value;
}
######################################################################
## encode_base64 - from MIME::Base64
######################################################################
sub encode_base64 ($;$) {
    my $res = '';
    my $eol = $_[1];
    $eol = "\n" unless defined $eol;
    pos($_[0]) = 0;                          # ensure start at the beginning
    while ($_[0] =~ /(.{1,45})/gs) {
        $res .= substr(pack('u', $1), 1);
        chop($res);
    }
    $res =~ tr|` -_|AA-Za-z0-9+/|;               # `# help emacs

    # fix padding at the end
    my $padding = (3 - length($_[0]) % 3) % 3;
    $res =~ s/.{$padding}$/'=' x $padding/e if $padding;
    $res;
}
######################################################################
## load_ssl_support
######################################################################
sub load_ssl_support {
    my $ssl_loaded = eval {require IO::Socket::SSL};
    unless ($ssl_loaded) {
        fatal(<<"EOM");
Error loading the Perl module IO::Socket::SSL needed for SSL connect.
On Debian, the package libio-socket-ssl-perl must be installed.
On Red Hat, the package perl-IO-Socket-SSL must be installed.
EOM
    }
    import  IO::Socket::SSL;
    { no warnings; $IO::Socket::SSL::DEBUG = 0; }
}
######################################################################
## load_sha1_support
######################################################################
sub load_sha1_support {
    my $sha1_loaded = eval {require Digest::SHA1};
    my $sha_loaded = eval {require Digest::SHA};
    unless ($sha1_loaded || $sha_loaded) {
        fatal(<<"EOM");
Error loading the Perl module Digest::SHA1 or Digest::SHA needed for freedns update.
On Debian, the package libdigest-sha1-perl or libdigest-sha-perl must be installed.
EOM
    }
    if($sha1_loaded) {
    	import  Digest::SHA1 (qw/sha1_hex/);
    } elsif($sha_loaded) {
    	import  Digest::SHA (qw/sha1_hex/);
    }
}
######################################################################
## geturl
######################################################################
sub geturl {
    my $proxy    = shift || '';
    my $url      = shift || '';
    my $login    = shift || '';
    my $password = shift || '';
    my ($peer, $server, $port, $default_port, $use_ssl);
    my ($sd, $rq, $request, $reply);

    debug("proxy  = $proxy");
    debug("url    = %s", $url);
    ## canonify proxy and url
    my $force_ssl;
    $force_ssl = 1 if ($url =~ /^https:/);
    $proxy  =~ s%^https?://%%i;
    $url    =~ s%^https?://%%i;
    $server = $url;
    $server =~ s%/.*%%;
    $url    = "/" unless $url =~ m%/%;
    $url    =~ s%^[^/]*/%%;
 
    debug("server = $server");
    opt('fw') && debug("opt(fw = ",opt('fw'),")");
    $globals{'fw'} && debug("glo fw = $globals{'fw'}"); 
    #if ( $globals{'ssl'} and $server ne $globals{'fw'} ) {
    ## always omit SSL for connections to local router
    if ( $force_ssl || ($globals{'ssl'} and (caller(1))[3] ne 'main::get_ip') ) {
        $use_ssl      = 1;
        $default_port = 443;
		load_ssl_support;
    } else {
        $use_ssl      = 0;
        $default_port = 80;
    }
   
    ## determine peer and port to use.
    $peer   = $proxy || $server;
    $peer   =~ s%/.*%%;
    $port   = $peer;
    $port   =~ s%^.*:%%;
    $port   = $default_port unless $port =~ /^\d+$/;
    $peer   =~ s%:.*$%%;
  
    my $to =  sprintf "%s%s", $server, $proxy ? " via proxy $peer:$port" : "";
    verbose("CONNECT:", "%s", $to);

    $request  = "GET ";
    $request .= "http://$server" if $proxy;
    $request .= "/$url HTTP/1.0\n";
    $request .= "Host: $server\n";

    my $auth = encode_base64("${login}:${password}");
    $request .= "Authorization: Basic $auth\n" if $login || $password;
    $request .= "User-Agent: ${program}/${version}\n";
    $request .= "Connection: close\n";
    $request .= "\n";

    ## make sure newlines are <cr><lf> for some pedantic proxy servers
    ($rq = $request) =~ s/\n/\r\n/g;

    # local $^W = 0;
    $0 = sprintf("%s - connecting to %s port %s", $program, $peer, $port);
    if (! opt('exec')) {
	debug("skipped network connection");
	verbose("SENDING:", "%s", $request);
    } elsif ($use_ssl) {
	    $sd = IO::Socket::SSL->new(
            PeerAddr => $peer,
            PeerPort => $port,
            Proto => 'tcp',
            MultiHomed => 1,
            Timeout => opt('timeout'),
        );
	    defined $sd or warning("cannot connect to $peer:$port socket: $@ " . IO::Socket::SSL::errstr());
    } else {
	    $sd = IO::Socket::INET->new(
            PeerAddr => $peer,
            PeerPort => $port,
            Proto => 'tcp',
            MultiHomed => 1,
            Timeout => opt('timeout'),
        );
	    defined $sd or warning("cannot connect to $peer:$port socket: $@");
    }

	if (defined $sd) {
		## send the request to the http server
		verbose("CONNECTED: ", $use_ssl ? 'using SSL' : 'using HTTP');
		verbose("SENDING:", "%s", $request);

		$0 = sprintf("%s - sending to %s port %s", $program, $peer, $port);
		my $result = syswrite $sd, $rq;
		if ($result != length($rq)) {
			warning("cannot send to $peer:$port ($!).");
		} else {
			$0 = sprintf("%s - reading from %s port %s", $program, $peer, $port);
			eval {
				local $SIG{'ALRM'} = sub { die "timeout";};
				alarm(opt('timeout')) if opt('timeout') > 0;
				while ($_ = <$sd>) {
					$0 = sprintf("%s - read from %s port %s", $program, $peer, $port);
					verbose("RECEIVE:", "%s", define($_, "<undefined>"));
					$reply .= $_ if defined $_;
				}
				if (opt('timeout') > 0) {
					alarm(0);
				}
			};
			close($sd);

			if ($@ and $@ =~ /timeout/) {
				warning("TIMEOUT: %s after %s seconds", $to, opt('timeout'));
				$reply = '';
			}
			$reply = '' if !defined $reply;
		}
	}
	$0 = sprintf("%s - closed %s port %s", $program, $peer, $port);

    ## during testing simulate reading the URL
    if (opt('test')) {
	my $filename = "$server/$url";
	$filename =~ s|/|%2F|g;
	if (opt('exec')) {
	    $reply = save_file("${savedir}$filename", $reply, 'unique');
	} else {
	    $reply = load_file("${savedir}$filename");
	}
    }

    $reply =~ s/\r//g if defined $reply;
    return $reply;
}
######################################################################
## get_ip
######################################################################
sub get_ip {
    my $use = lc shift;
    my $h = shift;
    my ($ip, $arg, $reply, $url, $skip) = (undef, opt($use, $h), '');
    $arg = '' unless $arg;

    if ($use eq 'ip') {
	$ip  = opt('ip', $h);
	$arg = 'ip';

    } elsif ($use eq 'if') {
	$skip  = opt('if-skip', $h)  || '';
	$reply = `ifconfig $arg 2> /dev/null`;
	$reply = `ip addr list dev $arg 2> /dev/null` if $?;
	$reply = '' if $?;

    } elsif ($use eq 'cmd') {
	if ($arg) {
	    $skip  = opt('cmd-skip', $h)  || '';
	    $reply = `$arg`;
	    $reply = '' if $?;
	}

    } elsif ($use eq 'web') {
	$url  = opt('web', $h)       || '';
	$skip = opt('web-skip', $h)  || '';

	if (exists $builtinweb{$url}) {
	    $skip = $builtinweb{$url}->{'skip'} unless $skip;
	    $url  = $builtinweb{$url}->{'url'};
	}	    
	$arg = $url;

	if ($url) {
	    $reply = geturl(opt('proxy', $h), $url) || '';
        }

    } elsif (($use eq 'cisco')) {
	# Stuff added to support Cisco router ip http daemon
	# User fw-login should only have level 1 access to prevent
	# password theft.  This is pretty harmless.
	my $queryif  = opt('if', $h);
	$skip = opt('fw-skip', $h)  || '';

	# Convert slashes to protected value "\/"
	$queryif =~ s%\/%\\\/%g;

	# Protect special HTML characters (like '?')
	$queryif =~ s/([\?&= ])/sprintf("%%%02x",ord($1))/ge;

	$url   = "http://".opt('fw', $h)."/level/1/exec/show/ip/interface/brief/${queryif}/CR";
	$reply = geturl('', $url, opt('fw-login', $h), opt('fw-password', $h)) || '';
	$arg   = $url;

    } elsif (($use eq 'cisco-asa')) {
	# Stuff added to support Cisco ASA ip https daemon
	# User fw-login should only have level 1 access to prevent
	# password theft.  This is pretty harmless.
	my $queryif  = opt('if', $h);
	$skip = opt('fw-skip', $h)  || '';

	# Convert slashes to protected value "\/"
	$queryif =~ s%\/%\\\/%g;

	# Protect special HTML characters (like '?')
	$queryif =~ s/([\?&= ])/sprintf("%%%02x",ord($1))/ge;

	$url   = "https://".opt('fw', $h)."/exec/show%20interface%20${queryif}";
	$reply = geturl('', $url, opt('fw-login', $h), opt('fw-password', $h)) || '';
	$arg   = $url;

    } else {
	$url  = opt('fw', $h)       || '';
	$skip = opt('fw-skip', $h)  || '';

	if (exists $builtinfw{$use}) {
	    $skip = $builtinfw{$use}->{'skip'} unless $skip;
	    $url  = "http://${url}" . $builtinfw{$use}->{'url'} unless $url =~ /\//;
	}	    
	$arg = $url;

	if ($url) {
	    $reply = geturl('', $url, opt('fw-login', $h), opt('fw-password', $h)) || '';
        }
    }
    if (!defined $reply) {
	$reply = '';
    }
    if ($skip) {
	$skip  =~ s/ /\\s/is;
    	$reply =~ s/^.*?${skip}//is;
    }
    if ($reply =~ /^.*?\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b.*/is) {
	$ip = $1;
    }
    if (($use ne 'ip') && (define($ip,'') eq '0.0.0.0')) {
	$ip = undef;
    }

    debug("get_ip: using %s, %s reports %s", $use, $arg, define($ip, "<undefined>"));
    return $ip;
}

######################################################################
## group_hosts_by
######################################################################
sub group_hosts_by {
    my ($hosts, $attributes) = @_;

    my %groups = ();
    foreach my $h (@$hosts) {
	my @keys = (@$attributes, 'wantip');
	map { $config{$h}{$_} = '' unless exists $config{$h}{$_} } @keys;
	my $sig  = join(',', map { "$_=$config{$h}{$_}" } @keys);

	push @{$groups{$sig}}, $h;
    }
    return %groups;
}
######################################################################
## nic_examples
######################################################################
sub nic_examples {
    my $examples  = "";
    my $separator = "";
    foreach my $s (sort keys %services)  {
	my $subr = $services{$s}{'examples'};
        my $example;

	if (defined($subr) && ($example = &$subr())) {
	    chomp($example);
	    $examples  .= $example;
	    $examples  .= "\n\n$separator";
	    $separator  = "\n";
	}
    }
    my $intro = <<EoEXAMPLE;
== CONFIGURING ${program}

The configuration file, ${program}.conf, can be used to define the
default behaviour and operation of ${program}.  The file consists of
sequences of global variable definitions and host definitions.

Global definitions look like:
  name=value [,name=value]*

For example:
  daemon=5m                   
  use=if, if=eth0             
  proxy=proxy.myisp.com       
  protocol=dyndns2

specifies that ${program} should operate as a daemon, checking the
eth0 interface for an IP address change every 5 minutes and use the
'dyndns2' protocol by default. The daemon interval can be specified
as seconds (600s), minutes (5m), hours (1h) or days (1d).

Host definitions look like:
  [name=value [,name=value]*]* a.host.domain [,b.host.domain] [login] [password]

For example:
  protocol=hammernode1, \\
  login=my-hn-login, password=my-hn-password  myhost.hn.org
  login=my-login, password=my-password  myhost.dyndns.org,my2nd.dyndns.org

specifies two host definitions.  

The first definition will use the hammernode1 protocol,
my-hn-login and my-hn-password to update the ip-address of
myhost.hn.org and my2ndhost.hn.org.

The second host definition will use the current default protocol
('dyndns2'), my-login and my-password to update the ip-address of
myhost.dyndns.org and my2ndhost.dyndns.org.

The order of this sequence is significant because the values of any
global variable definitions are bound to a host definition when the
host definition is encountered.

See the sample-${program}.conf file for further examples.
EoEXAMPLE
    $intro .= "\n== NIC specific variables and examples:\n$examples" if $examples;
    return $intro;
}
######################################################################
## nic_updateable
######################################################################
sub nic_updateable {
    my $host   = shift;
    my $sub    = shift;
    my $update = 0;
    my $ip     = $config{$host}{'wantip'};

    if ($config{$host}{'login'} eq '') {
	warning("null login name specified for host %s.", $host);

    } elsif ($config{$host}{'password'} eq '') {
	warning("null password specified for host %s.", $host);

    } elsif ($opt{'force'}) {
	info("forcing update of %s.", $host);
	$update = 1;

    } elsif (!exists($cache{$host})) {
	info("forcing updating %s because no cached entry exists.", $host);
	$update = 1;

    } elsif ($cache{$host}{'wtime'} && $cache{$host}{'wtime'} > $now) {
	warning("cannot update %s from %s to %s until after %s.", 
		$host, 
		($cache{$host}{'ip'} ? $cache{$host}{'ip'} : '<nothing>'), $ip,
		prettytime($cache{$host}{'wtime'})
	);

    } elsif ($cache{$host}{'mtime'} && interval_expired($host, 'mtime', 'max-interval')) {
	warning("forcing update of %s from %s to %s; %s since last update on %s.", 
		$host, 
		($cache{$host}{'ip'} ? $cache{$host}{'ip'} : '<nothing>'), $ip,
		prettyinterval($config{$host}{'max-interval'}),
		prettytime($cache{$host}{'mtime'})
	);
	$update = 1;

    } elsif ((!exists($cache{$host}{'ip'})) ||
		    ("$cache{$host}{'ip'}" ne "$ip")) {
	    if (($cache{$host}{'status'} eq 'good') && 
			    !interval_expired($host, 'mtime', 'min-interval')) {

	    warning("skipping update of %s from %s to %s.\nlast updated %s.\nWait at least %s between update attempts.", 
		 $host, 
		 ($cache{$host}{'ip'}    ? $cache{$host}{'ip'}                : '<nothing>'), 
		 $ip,
		 ($cache{$host}{'mtime'} ? prettytime($cache{$host}{'mtime'}) : '<never>'),
		 prettyinterval($config{$host}{'min-interval'})		
		 )
		if opt('verbose') || !define($cache{$host}{'warned-min-interval'}, 0);

	    $cache{$host}{'warned-min-interval'} = $now;
	    
	} elsif (($cache{$host}{'status'} ne 'good') && !interval_expired($host, 'atime', 'min-error-interval')) {

	    warning("skipping update of %s from %s to %s.\nlast updated %s but last attempt on %s failed.\nWait at least %s between update attempts.", 
		 $host, 
		 ($cache{$host}{'ip'}    ? $cache{$host}{'ip'}                : '<nothing>'), 
		 $ip,
		 ($cache{$host}{'mtime'} ? prettytime($cache{$host}{'mtime'}) : '<never>'),
		 ($cache{$host}{'atime'} ? prettytime($cache{$host}{'atime'}) : '<never>'),
		 prettyinterval($config{$host}{'min-error-interval'})		
		 )
		if opt('verbose') || !define($cache{$host}{'warned-min-error-interval'}, 0);

	    $cache{$host}{'warned-min-error-interval'} = $now;

	} else {
	    $update = 1;
	}

    } elsif (defined($sub) && &$sub($host)) {
	$update = 1;
    } elsif ((defined($cache{$host}{'static'}) && defined($config{$host}{'static'}) &&
              ($cache{$host}{'static'} ne $config{$host}{'static'})) ||
             (defined($cache{$host}{'wildcard'}) && defined($config{$host}{'wildcard'}) &&
              ($cache{$host}{'wildcard'} ne $config{$host}{'wildcard'})) ||
             (defined($cache{$host}{'mx'}) && defined($config{$host}{'mx'}) &&
              ($cache{$host}{'mx'} ne $config{$host}{'mx'})) ||
             (defined($cache{$host}{'backupmx'}) && defined($config{$host}{'backupmx'}) &&
              ($cache{$host}{'backupmx'} ne $config{$host}{'backupmx'})) ) {
	info("updating %s because host settings have been changed.", $host);
	$update = 1;

    } else {
	success("%s: skipped: IP address was already set to %s.", $host, $ip)
	    if opt('verbose');
    }
    $config{$host}{'status'} = define($cache{$host}{'status'},'');
    $config{$host}{'update'} = $update;
    if ($update) {
	$config{$host}{'status'}                    = 'noconnect';
	$config{$host}{'atime'}                     = $now;
	$config{$host}{'wtime'}                     = 0;
	$config{$host}{'warned-min-interval'}       = 0;
	$config{$host}{'warned-min-error-interval'} = 0;

	delete $cache{$host}{'warned-min-interval'};
	delete $cache{$host}{'warned-min-error-interval'};
    }
	    
    return $update;
}
######################################################################
## header_ok
######################################################################
sub header_ok {
    my ($host, $line) = @_;
    my $ok = 0;

    if ($line =~ m%^s*HTTP/1.*\s+(\d+)%i) {
	my $result = $1;

	if ($result eq '200') {
	    $ok = 1;

	} elsif ($result eq '401') {
	    failed("updating %s: authorization failed (%s)", $host, $line);
	}
	
    } else {
	failed("updating %s: unexpected line (%s)", $host, $line);
    }
    return $ok;
}
######################################################################
## nic_dyndns1_examples
######################################################################
sub nic_dyndns1_examples {
    return <<EoEXAMPLE;
o 'dyndns1'

The 'dyndns1' protocol is a deprecated protocol used by the free dynamic
DNS service offered by www.dyndns.org. The 'dyndns2' should be used to
update the www.dyndns.org service.  However, other services are also 
using this protocol so support is still provided by ${program}.

Configuration variables applicable to the 'dyndns1' protocol are:
  protocol=dyndns1             ## 
  server=fqdn.of.service       ## defaults to members.dyndns.org
  backupmx=no|yes              ## indicates that this host is the primary MX for the domain.
  mx=any.host.domain           ## a host MX'ing for this host definition.
  wildcard=no|yes              ## add a DNS wildcard CNAME record that points to {host}
  login=service-login          ## login name and password  registered with the service
  password=service-password    ##
  fully.qualified.host         ## the host registered with the service.

Example ${program}.conf file entries:
  ## single host update
  protocol=dyndns1,                                         \\
  login=my-dyndns.org-login,                                \\
  password=my-dyndns.org-password                           \\
  myhost.dyndns.org 

  ## multiple host update with wildcard'ing mx, and backupmx
  protocol=dyndns1,                                         \\
  login=my-dyndns.org-login,                                \\
  password=my-dyndns.org-password,                          \\
  mx=a.host.willing.to.mx.for.me,backupmx=yes,wildcard=yes  \\
  myhost.dyndns.org,my2ndhost.dyndns.org 
EoEXAMPLE
}
######################################################################
## nic_dyndns1_update
######################################################################
sub nic_dyndns1_update {
    debug("\nnic_dyndns1_update -------------------");
    ## update each configured host
    foreach my $h (@_) {
	my $ip = delete $config{$h}{'wantip'};
	info("setting IP address to %s for %s", $ip, $h);
	verbose("UPDATE:","updating %s", $h);

	my $url;
	$url   = "http://$config{$h}{'server'}/nic/";
	$url  .= ynu($config{$h}{'static'}, 'statdns', 'dyndns', 'dyndns');
	$url  .= "?action=edit&started=1&hostname=YES&host_id=$h";
	$url  .= "&myip=";
	$url  .= $ip            if $ip;
	$url  .= "&wildcard=ON" if ynu($config{$h}{'wildcard'}, 1, 0, 0);
	if ($config{$h}{'mx'}) {
	    $url .= "&mx=$config{$h}{'mx'}";
	    $url .= "&backmx=" . ynu($config{$h}{'backupmx'}, 'YES', 'NO');
	}
	
	my $reply = geturl(opt('proxy'), $url, $config{$h}{'login'}, $config{$h}{'password'});
	if (!defined($reply) || !$reply) {
	    failed("updating %s: Could not connect to %s.", $h, $config{$h}{'server'});
	    next;
	}
	last if !header_ok($h, $reply);

	my @reply = split /\n/, $reply;
	my ($title, $return_code, $error_code) = ('','','');
	foreach my $line (@reply) {
	    $title       = $1 if $line =~ m%<TITLE>\s*(.*)\s*</TITLE>%i;
	    $return_code = $1 if $line =~ m%^return\s+code\s*:\s*(.*)\s*$%i;
	    $error_code  = $1 if $line =~ m%^error\s+code\s*:\s*(.*)\s*$%i;
	}
	
	if ($return_code ne 'NOERROR' || $error_code ne 'NOERROR' || !$title) {
	    $config{$h}{'status'} = 'failed';
	    $title = "incomplete response from $config{$h}{server}" unless $title;
	    warning("SENT:    %s", $url) unless opt('verbose');
	    warning("REPLIED: %s", $reply);
	    failed("updating %s: %s", $h, $title);
	    
	} else {
	    $config{$h}{'ip'}     = $ip;
	    $config{$h}{'mtime'}  = $now;
	    $config{$h}{'status'} = 'good';
	    success("updating %s: %s: IP address set to %s (%s)", $h, $return_code, $ip, $title);
	}
    }
}
######################################################################
## nic_dyndns2_updateable
######################################################################
sub nic_dyndns2_updateable {
    my $host   = shift;
    my $update = 0;

    if ($config{$host}{'mx'} ne $cache{$host}{'mx'}) {
	info("forcing updating %s because 'mx' has changed to %s.", $host, $config{$host}{'mx'});
	$update = 1;

    } elsif ($config{$host}{'mx'} && (ynu($config{$host}{'backupmx'},1,2,3) ne ynu($config{$host}{'backupmx'},1,2,3))) {
	info("forcing updating %s because 'backupmx' has changed to %s.", $host, ynu($config{$host}{'backupmx'},"YES","NO","NO"));
	$update = 1;

    } elsif ($config{$host}{'static'} ne $cache{$host}{'static'}) {

	info("forcing updating %s because 'static' has changed to %s.", $host, ynu($config{$host}{'static'},"YES","NO","NO"));
	$update = 1;

    }
    return $update;
}
######################################################################
## nic_dyndns2_examples
######################################################################
sub nic_dyndns2_examples {
    return <<EoEXAMPLE;
o 'dyndns2'

The 'dyndns2' protocol is a newer low-bandwidth protocol used by a
free dynamic DNS service offered by www.dyndns.org.  It supports
features of the older 'dyndns1' in addition to others.  [These will be
supported in a future version of ${program}.]

Configuration variables applicable to the 'dyndns2' protocol are:
  protocol=dyndns2             ## 
  server=fqdn.of.service       ## defaults to members.dyndns.org
  script=/path/to/script       ## defaults to /nic/update
  backupmx=no|yes              ## indicates that this host is the primary MX for the domain.
  static=no|yes                ## indicates that this host has a static IP address.
  custom=no|yes                ## indicates that this host is a 'custom' top-level domain name.
  mx=any.host.domain           ## a host MX'ing for this host definition.
  wildcard=no|yes              ## add a DNS wildcard CNAME record that points to {host}
  login=service-login          ## login name and password  registered with the service
  password=service-password    ##
  fully.qualified.host         ## the host registered with the service.

Example ${program}.conf file entries:
  ## single host update
  protocol=dyndns2,                                         \\
  login=my-dyndns.org-login,                                \\
  password=my-dyndns.org-password                           \\
  myhost.dyndns.org 

  ## multiple host update with wildcard'ing mx, and backupmx
  protocol=dyndns2,                                         \\
  login=my-dyndns.org-login,                                \\
  password=my-dyndns.org-password,                          \\
  mx=a.host.willing.to.mx.for.me,backupmx=yes,wildcard=yes  \\
  myhost.dyndns.org,my2ndhost.dyndns.org 

  ## multiple host update to the custom DNS service
  protocol=dyndns2,                                         \\
  login=my-dyndns.org-login,                                \\
  password=my-dyndns.org-password                           \\
  my-toplevel-domain.com,my-other-domain.com
EoEXAMPLE
}
######################################################################
## nic_dyndns2_update
######################################################################
sub nic_dyndns2_update {
    debug("\nnic_dyndns2_update -------------------");

    ## group hosts with identical attributes together 
    my %groups = group_hosts_by([ @_ ], [ qw(login password server static custom wildcard mx backupmx) ]);

    my %errors = (
       'badauth'  => 'Bad authorization (username or password)',
       'badsys'   => 'The system parameter given was not valid',

       'notfqdn'  => 'A Fully-Qualified Domain Name was not provided',
       'nohost'   => 'The hostname specified does not exist in the database',
       '!yours'   => 'The hostname specified exists, but not under the username currently being used',
       '!donator' => 'The offline setting was set, when the user is not a donator',
       '!active'  => 'The hostname specified is in a Custom DNS domain which has not yet been activated.',
       'abuse',   => 'The hostname specified is blocked for abuse; you should receive an email notification ' . 
                     'which provides an unblock request link.  More info can be found on ' . 
                     'https://www.dyndns.com/support/abuse.html',

       'numhost'  => 'System error: Too many or too few hosts found. Contact support@dyndns.org',
       'dnserr'   => 'System error: DNS error encountered. Contact support@dyndns.org',

       'nochg'    => 'No update required; unnecessary attempts to change to the current address are considered abusive',
    );

    ## update each set of hosts that had similar configurations
    foreach my $sig (keys %groups) {
	my @hosts = @{$groups{$sig}};
	my $hosts = join(',', @hosts);
	my $h     = $hosts[0];
	my $ip    = $config{$h}{'wantip'};
	delete $config{$_}{'wantip'} foreach @hosts;

	info("setting IP address to %s for %s", $ip, $hosts);
	verbose("UPDATE:","updating %s", $hosts);

	## Select the DynDNS system to update
	my $url = "http://$config{$h}{'server'}$config{$h}{'script'}?system=";
	if ($config{$h}{'custom'}) {
	    warning("updating %s: 'custom' and 'static' may not be used together. ('static' ignored)", $hosts)
	      if $config{$h}{'static'};
#	    warning("updating %s: 'custom' and 'offline' may not be used together. ('offline' ignored)", $hosts)
#	      if $config{$h}{'offline'};
	    $url .= 'custom';

	} elsif  ($config{$h}{'static'}) {
#	    warning("updating %s: 'static' and 'offline' may not be used together. ('offline' ignored)", $hosts)
#	      if $config{$h}{'offline'};
	    $url .= 'statdns';

	} else {
	    $url .= 'dyndns';
	}

	$url  .= "&hostname=$hosts";
	$url  .= "&myip=";
	$url  .= $ip            if $ip;

	## some args are not valid for a custom domain.
	$url  .= "&wildcard=ON" if ynu($config{$h}{'wildcard'}, 1, 0, 0);
	if ($config{$h}{'mx'}) {
	    $url .= "&mx=$config{$h}{'mx'}";
	    $url .= "&backmx=" . ynu($config{$h}{'backupmx'}, 'YES', 'NO');
	}

	my $reply = geturl(opt('proxy'), $url, $config{$h}{'login'}, $config{$h}{'password'});
	if (!defined($reply) || !$reply) {
	    failed("updating %s: Could not connect to %s.", $hosts, $config{$h}{'server'});
	    last;
	}
	last if !header_ok($hosts, $reply);

	my @reply = split /\n/, $reply;
	my $state = 'header';
	my $returnedip = $ip;

	foreach my $line (@reply) {
	    if ($state eq 'header') {
		$state = 'body';
	    
	    } elsif ($state eq 'body') {
		$state = 'results' if $line eq '';
	    
	    } elsif ($state =~ /^results/) {
		$state = 'results2';

		# bug #10: some dyndns providers does not return the IP so
		# we can't use the returned IP
		my ($status, $returnedip) = split / /, lc $line;
		$ip = $returnedip if (not $ip);
		my $h = shift @hosts;
	    
		$config{$h}{'status'} = $status;
		if ($status eq 'good') {
		    $config{$h}{'ip'}     = $ip;
		    $config{$h}{'mtime'}  = $now;
		    success("updating %s: %s: IP address set to %s", $h, $status, $ip);
		
		} elsif (exists $errors{$status}) {
		    if ($status eq 'nochg') {
			warning("updating %s: %s: %s", $h, $status, $errors{$status});
			$config{$h}{'ip'}     = $ip;
		    	$config{$h}{'mtime'}  = $now;
			$config{$h}{'status'} = 'good';
		    
		    } else {
			failed("updating %s: %s: %s", $h, $status, $errors{$status});
		    }

		} elsif ($status =~ /w(\d+)(.)/) {
		    my ($wait, $units) = ($1, lc $2);
		    my ($sec,  $scale) = ($wait, 1);
		
		    ($scale, $units) = (1, 'seconds')   if $units eq 's';
		    ($scale, $units) = (60, 'minutes')  if $units eq 'm';
		    ($scale, $units) = (60*60, 'hours') if $units eq 'h';

		    $sec = $wait * $scale;
		    $config{$h}{'wtime'} = $now + $sec;
		    warning("updating %s: %s: wait $wait $units before further updates", $h, $status, $ip);
		
		} else {
		    failed("updating %s: %s: unexpected status (%s)", $h, $line);
		} 	
	    }
	}
	failed("updating %s: Could not connect to %s.", $hosts, $config{$h}{'server'})
	    if $state ne 'results2';
    }
}


######################################################################
## nic_noip_update
## Note: uses same features as nic_dyndns2_update, less return codes
######################################################################
sub nic_noip_update {
    debug("\nnic_noip_update -------------------");

    ## group hosts with identical attributes together 
    my %groups = group_hosts_by([ @_ ], [ qw(login password server static custom wildcard mx backupmx) ]);

    my %errors = (
       'badauth'  => 'Invalid username or password',
       'badagent' => 'Invalid user agent',
       'nohost'   => 'The hostname specified does not exist in the database',
       '!donator' => 'The offline setting was set, when the user is not a donator',
       'abuse',   => 'The hostname specified is blocked for abuse; open a trouble ticket at http://www.no-ip.com',
       'numhost'  => 'System error: Too many or too few hosts found. open a trouble ticket at http://www.no-ip.com',
       'dnserr'   => 'System error: DNS error encountered. Contact support@dyndns.org',
       'nochg'    => 'No update required; unnecessary attempts to change to the current address are considered abusive',
    );

    ## update each set of hosts that had similar configurations
    foreach my $sig (keys %groups) {
	my @hosts = @{$groups{$sig}};
	my $hosts = join(',', @hosts);
	my $h     = $hosts[0];
	my $ip    = $config{$h}{'wantip'};
	delete $config{$_}{'wantip'} foreach @hosts;

	info("setting IP address to %s for %s", $ip, $hosts);
	verbose("UPDATE:","updating %s", $hosts);

	my $url = "http://$config{$h}{'server'}/nic/update?system=";
    $url .= 'noip';
	$url  .= "&hostname=$hosts";
	$url  .= "&myip=";
	$url  .= $ip            if $ip;


	print "here..." . $config{$h}{'login'} . " --> " . $config{$h}{'password'} . "\n";
	

	my $reply = geturl(opt('proxy'), $url, $config{$h}{'login'}, $config{$h}{'password'});
	if (!defined($reply) || !$reply) {
	    failed("updating %s: Could not connect to %s.", $hosts, $config{$h}{'server'});
	    last;
	}
	last if !header_ok($hosts, $reply);

	my @reply = split /\n/, $reply;
	my $state = 'header';
	foreach my $line (@reply) {
	    if ($state eq 'header') {
		$state = 'body';
	    
	    } elsif ($state eq 'body') {
		$state = 'results' if $line eq '';
	    
	    } elsif ($state =~ /^results/) {
		$state = 'results2';

		my ($status, $ip) = split / /, lc $line;
		my $h = shift @hosts;
	    
		$config{$h}{'status'} = $status;
		if ($status eq 'good') {
		    $config{$h}{'ip'}     = $ip;
		    $config{$h}{'mtime'}  = $now;
		    success("updating %s: %s: IP address set to %s", $h, $status, $ip);
		
		} elsif (exists $errors{$status}) {
		    if ($status eq 'nochg') {
			warning("updating %s: %s: %s", $h, $status, $errors{$status});
			$config{$h}{'ip'}     = $ip;
		    	$config{$h}{'mtime'}  = $now;
			$config{$h}{'status'} = 'good';
		    
		    } else {
			failed("updating %s: %s: %s", $h, $status, $errors{$status});
		    }

		} elsif ($status =~ /w(\d+)(.)/) {
		    my ($wait, $units) = ($1, lc $2);
		    my ($sec,  $scale) = ($wait, 1);
		
		    ($scale, $units) = (1, 'seconds')   if $units eq 's';
		    ($scale, $units) = (60, 'minutes')  if $units eq 'm';
		    ($scale, $units) = (60*60, 'hours') if $units eq 'h';

		    $sec = $wait * $scale;
		    $config{$h}{'wtime'} = $now + $sec;
		    warning("updating %s: %s: wait $wait $units before further updates", $h, $status, $ip);
		
		} else {
		    failed("updating %s: %s: unexpected status (%s)", $h, $line);
		} 	
	    }
	}
	failed("updating %s: Could not connect to %s.", $hosts, $config{$h}{'server'})
	    if $state ne 'results2';
    }
}
######################################################################
## nic_noip_examples
######################################################################
sub nic_noip_examples {
    return <<EoEXAMPLE;
o 'noip'

The 'No-IP Compatible' protocol is used to make dynamic dns updates
over an http request.  Details of the protocol are outlined at:
http://www.no-ip.com/integrate/

Configuration variables applicable to the 'noip' protocol are:
  protocol=noip		           ## 
  server=fqdn.of.service       ## defaults to dynupdate.no-ip.com
  login=service-login          ## login name and password  registered with the service
  password=service-password    ##
  fully.qualified.host         ## the host registered with the service.

Example ${program}.conf file entries:
  ## single host update
  protocol=noip,                                        \\
  login=userlogin\@domain.com,                                \\
  password=noip-password                           \\
  myhost.no-ip.biz 


EoEXAMPLE
}

######################################################################
## nic_concont_examples
######################################################################
sub nic_concont_examples {
    return <<EoEXAMPLE; 
o 'concont'
                          
The 'concont' protocol is the protocol used by the content management
system ConCont's dydns module. This is currently used by the free
dynamic DNS service offered by Tyrmida at www.dydns.za.net
    
Configuration variables applicable to the 'concont' protocol are:
  protocol=concont             ## 
  server=www.fqdn.of.service   ## for example www.dydns.za.net (for most add a www)
  login=service-login          ## login registered with the service
  password=service-password    ## password registered with the service
  mx=mail.server.fqdn          ## fqdn of the server handling domain\'s mail (leave out for none)
  wildcard=yes|no              ## set yes for wild (*.host.domain) support
  fully.qualified.host         ## the host registered with the service.
                        
Example ${program}.conf file entries:
  ## single host update
  protocol=concont,                                     \\
  login=dydns.za.net,                                   \\
  password=my-dydns.za.net-password,                    \\
  mx=mailserver.fqdn,                                   \\
  wildcard=yes                                          \\
  myhost.hn.org           
                        
EoEXAMPLE
}
######################################################################
## nic_concont_update
######################################################################
sub nic_concont_update {
    debug("\nnic_concont_update -------------------");

    ## update each configured host
    foreach my $h (@_) {
	my $ip = delete $config{$h}{'wantip'};
        info("setting IP address to %s for %s", $ip, $h);
        verbose("UPDATE:","updating %s", $h);

        # Set the URL that we're going to to update
        my $url;
        $url  = "http://$config{$h}{'server'}/modules/dydns/update.php";
        $url .= "?username=";
        $url .= $config{$h}{'login'};
        $url .= "&password=";
        $url .= $config{$h}{'password'};
        $url .= "&wildcard=";
        $url .= $config{$h}{'wildcard'};
        $url .= "&mx=";
        $url .= $config{$h}{'mx'};
        $url .= "&host=";
        $url .= $h;
        $url .= "&ip=";
        $url .= $ip;

        # Try to get URL
        my $reply = geturl(opt('proxy'), $url);

        # No response, declare as failed
        if (!defined($reply) || !$reply) {
            failed("updating %s: Could not connect to %s.", $h, $config{$h}{'server'});
            last;
        }
        last if !header_ok($h, $reply);

        # Response found, just declare as success (this is ugly, we need more error checking)
        if ($reply =~ /SUCCESS/)
        {
                $config{$h}{'ip'}     = $ip;
                $config{$h}{'mtime'}  = $now;
                $config{$h}{'status'} = 'good';
                success("updating %s: good: IP address set to %s", $h, $ip);
         }
         else
         {
                my @reply = split /\n/, $reply;
                my $returned = pop(@reply);
                $config{$h}{'status'} = 'failed';
                failed("updating %s: Server said: '$returned'", $h);
         }
    }
}
######################################################################
## nic_dslreports1_examples
######################################################################
sub nic_dslreports1_examples {
    return <<EoEXAMPLE;
o 'dslreports1'

The 'dslreports1' protocol is used by a free DSL monitoring service
offered by www.dslreports.com. 

Configuration variables applicable to the 'dslreports1' protocol are:
  protocol=dslreports1         ## 
  server=fqdn.of.service       ## defaults to www.dslreports.com
  login=service-login          ## login name and password  registered with the service
  password=service-password    ##
  unique-number                ## the host registered with the service.

Example ${program}.conf file entries:
  ## single host update
  protocol=dslreports1,                                     \\
  server=www.dslreports.com,                                \\
  login=my-dslreports-login,                                \\
  password=my-dslreports-password                           \\
  123456

Note: DSL Reports uses a unique number as the host name.  This number
can be found on the Monitor Control web page.
EoEXAMPLE
}
######################################################################
## nic_dslreports1_update
######################################################################
sub nic_dslreports1_update {
    debug("\nnic_dslreports1_update -------------------");
    ## update each configured host
    foreach my $h (@_) {
	my $ip = delete $config{$h}{'wantip'};
	info("setting IP address to %s for %s", $ip, $h);
	verbose("UPDATE:","updating %s", $h);

	my $url;
	$url   = "http://$config{$h}{'server'}/nic/";
	$url  .= ynu($config{$h}{'static'}, 'statdns', 'dyndns', 'dyndns');
	$url  .= "?action=edit&started=1&hostname=YES&host_id=$h";
	$url  .= "&myip=";
	$url  .= $ip            if $ip;
	
	my $reply = geturl(opt('proxy'), $url, $config{$h}{'login'}, $config{$h}{'password'});
	if (!defined($reply) || !$reply) {
	    failed("updating %s: Could not connect to %s.", $h, $config{$h}{'server'});
	    next;
	}
	
	my @reply = split /\n/, $reply;
	my $return_code = '';
	foreach my $line (@reply) {
	    $return_code = $1 if $line =~ m%^return\s+code\s*:\s*(.*)\s*$%i;
	}
	
	if ($return_code !~ /NOERROR/) {
	    $config{$h}{'status'} = 'failed';
	    warning("SENT:    %s", $url) unless opt('verbose');
	    warning("REPLIED: %s", $reply);
	    failed("updating %s", $h);
	    
	} else {
	    $config{$h}{'ip'}     = $ip;
	    $config{$h}{'mtime'}  = $now;
	    $config{$h}{'status'} = 'good';
	    success("updating %s: %s: IP address set to %s", $h, $return_code, $ip);
	}
    }
}
######################################################################
## nic_hammernode1_examples
######################################################################
sub nic_hammernode1_examples {
    return <<EoEXAMPLE;
o 'hammernode1'

The 'hammernode1' protocol is the protocol used by the free dynamic
DNS service offered by Hammernode at www.hn.org

Configuration variables applicable to the 'hammernode1' protocol are:
  protocol=hammernode1         ## 
  server=fqdn.of.service       ## defaults to members.dyndns.org
  login=service-login          ## login name and password  registered with the service
  password=service-password    ##
  fully.qualified.host         ## the host registered with the service.

Example ${program}.conf file entries:
  ## single host update
  protocol=hammernode1,                                 \\
  login=my-hn.org-login,                                \\
  password=my-hn.org-password                           \\
  myhost.hn.org 

  ## multiple host update
  protocol=hammernode1,                                 \\
  login=my-hn.org-login,                                \\
  password=my-hn.org-password,                          \\
  myhost.hn.org,my2ndhost.hn.org
EoEXAMPLE
}
######################################################################
## nic_hammernode1_update
######################################################################
sub nic_hammernode1_update {
    debug("\nnic_hammernode1_update -------------------");

    ## update each configured host
    foreach my $h (@_) {
	my $ip = delete $config{$h}{'wantip'};
	info("setting IP address to %s for %s", $ip, $h);
	verbose("UPDATE:","updating %s", $h);

	my $url;
	$url   = "http://$config{$h}{'server'}/vanity/update";
	$url  .= "?ver=1";
	$url  .= "&ip=";
	$url  .= $ip if $ip;
	
	my $reply = geturl(opt('proxy'), $url, $config{$h}{'login'}, $config{$h}{'password'});
	if (!defined($reply) || !$reply) {
	    failed("updating %s: Could not connect to %s.", $h, $config{$h}{'server'});
	    last;
	}
	last if !header_ok($h, $reply);
	
	my @reply = split /\n/, $reply;
	if (grep /<!--\s+DDNS_Response_Code=101\s+-->/i, @reply) {
	    $config{$h}{'ip'}     = $ip;
	    $config{$h}{'mtime'}  = $now;
	    $config{$h}{'status'} = 'good';
	    success("updating %s: good: IP address set to %s", $h, $ip);
	} else {
	    $config{$h}{'status'} = 'failed';
	    warning("SENT:    %s", $url) unless opt('verbose');
	    warning("REPLIED: %s", $reply);
	    failed("updating %s: Invalid reply.", $h);
	}
    }
}
######################################################################
## nic_zoneedit1_examples
######################################################################
sub nic_zoneedit1_examples {
    return <<EoEXAMPLE;
o 'zoneedit1'

The 'zoneedit1' protocol is used by a DNS service offered by
www.zoneedit.com.

Configuration variables applicable to the 'zoneedit1' protocol are:
  protocol=zoneedit1           ## 
  server=fqdn.of.service       ## defaults to www.zoneedit.com
  zone=zone-where-domains-are  ## only needed if 1 or more subdomains are deeper
                               ## than 1 level in relation to  the zone where it
                               ## is defined. For example, b.foo.com in a zone
                               ## foo.com doesn't need this, but a.b.foo.com in
                               ## the same zone needs zone=foo.com
  login=service-login          ## login name and password  registered with the service
  password=service-password    ##
  your.domain.name             ## the host registered with the service.

Example ${program}.conf file entries:
  ## single host update
  protocol=zoneedit1,                                     \\
  server=dynamic.zoneedit.com,                            \\
  zone=zone-where-domains-are,                            \\
  login=my-zoneedit-login,                                \\
  password=my-zoneedit-password                           \\
  my.domain.name
EoEXAMPLE
}

######################################################################
## nic_zoneedit1_updateable
######################################################################
sub nic_zoneedit1_updateable {
    return 0;
}

######################################################################
## nic_zoneedit1_update
# <SUCCESS CODE="200" TEXT="Update succeeded." ZONE="trialdomain.com" IP="127.0.0.12">
# <SUCCESS CODE="201" TEXT="No records need updating." ZONE="bannedware.com">
# <ERROR CODE="701" TEXT="Zone is not set up in this account." ZONE="bad.com">
######################################################################
sub nic_zoneedit1_update {
    debug("\nnic_zoneedit1_update -------------------");

    ## group hosts with identical attributes together 
    my %groups = group_hosts_by([ @_ ], [ qw(login password server zone) ]);

    ## update each set of hosts that had similar configurations
    foreach my $sig (keys %groups) {
	my @hosts = @{$groups{$sig}};
	my $hosts = join(',', @hosts);
	my $h     = $hosts[0];
	my $ip    = $config{$h}{'wantip'};
	delete $config{$_}{'wantip'} foreach @hosts;

	info("setting IP address to %s for %s", $ip, $hosts);
	verbose("UPDATE:","updating %s", $hosts);

	my $url = '';
	$url  .= "http://$config{$h}{'server'}/auth/dynamic.html";
	$url  .= "?host=$hosts";
	$url  .= "&dnsto=$ip"   if $ip;
	$url  .= "&zone=$config{$h}{'zone'}" if defined $config{$h}{'zone'};

	my $reply = geturl(opt('proxy'), $url, $config{$h}{'login'}, $config{$h}{'password'});
	if (!defined($reply) || !$reply) {
	    failed("updating %s: Could not connect to %s.", $hosts, $config{$h}{'server'});
	    last;
	}
	last if !header_ok($hosts, $reply);

	my @reply = split /\n/, $reply;
	foreach my $line (@reply) {
	    if ($line =~ /^[^<]*<(SUCCESS|ERROR)\s+([^>]+)>(.*)/)  {
		my ($status, $assignments, $rest) = ($1, $2, $3);
		my ($left, %var) = parse_assignments($assignments);

		if (keys %var) {
		    my ($status_code, $status_text, $status_ip) = ('999', '', $ip);
		    $status_code = $var{'CODE'} if exists $var{'CODE'};
		    $status_text = $var{'TEXT'} if exists $var{'TEXT'};
		    $status_ip   = $var{'IP'}   if exists $var{'IP'};

		    if ($status eq 'SUCCESS' || ($status eq 'ERROR' && $var{'CODE'} eq '707')) {
			$config{$h}{'ip'}     = $status_ip;
			$config{$h}{'mtime'}  = $now;
	    		$config{$h}{'status'} = 'good';

			success("updating %s: IP address set to %s (%s: %s)", $h, $ip, $status_code, $status_text);

		    } else {
	    		$config{$h}{'status'} = 'failed';
			failed("updating %s: %s: %s", $h, $status_code, $status_text);
		    } 	
		    shift @hosts;
		    $h     = $hosts[0];
		    $hosts = join(',', @hosts);
		}
		$line = $rest;
		redo if $line;
	    }
	}
	failed("updating %s: no response from %s", $hosts, $config{$h}{'server'})
	      if @hosts;
    }
}	
######################################################################
## nic_easydns_updateable
######################################################################
sub nic_easydns_updateable {
    my $host   = shift;
    my $update = 0;

    if ($config{$host}{'mx'} ne $cache{$host}{'mx'}) {
	info("forcing updating %s because 'mx' has changed to %s.", $host, $config{$host}{'mx'});
	$update = 1;

    } elsif ($config{$host}{'mx'} && (ynu($config{$host}{'backupmx'},1,2,3) ne ynu($config{$host}{'backupmx'},1,2,3))) {
	info("forcing updating %s because 'backupmx' has changed to %s.", $host, ynu($config{$host}{'backupmx'},"YES","NO","NO"));
	$update = 1;

    } elsif ($config{$host}{'static'} ne $cache{$host}{'static'}) {

	info("forcing updating %s because 'static' has changed to %s.", $host, ynu($config{$host}{'static'},"YES","NO","NO"));
	$update = 1;

    }
    return $update;
}
######################################################################
## nic_easydns_examples
######################################################################
sub nic_easydns_examples {
    return <<EoEXAMPLE;
o 'easydns'

The 'easydns' protocol is used by the for fee DNS service offered 
by www.easydns.com.

Configuration variables applicable to the 'easydns' protocol are:
  protocol=easydns             ## 
  server=fqdn.of.service       ## defaults to members.easydns.com
  backupmx=no|yes              ## indicates that EasyDNS should be the secondary MX 
                               ## for this domain or host.
  mx=any.host.domain           ## a host MX'ing for this host or domain.
  wildcard=no|yes              ## add a DNS wildcard CNAME record that points to {host}
  login=service-login          ## login name and password  registered with the service
  password=service-password    ##
  fully.qualified.host         ## the host registered with the service.

Example ${program}.conf file entries:
  ## single host update
  protocol=easydns,                                         \\
  login=my-easydns.com-login,                               \\
  password=my-easydns.com-password                          \\
  myhost.easydns.com 

  ## multiple host update with wildcard'ing mx, and backupmx
  protocol=easydns,                                         \\
  login=my-easydns.com-login,                               \\
  password=my-easydns.com-password,                         \\
  mx=a.host.willing.to.mx.for.me,                           \\
  backupmx=yes,                                             \\
  wildcard=yes                                              \\
  my-toplevel-domain.com,my-other-domain.com

  ## multiple host update to the custom DNS service
  protocol=easydns,                                         \\
  login=my-easydns.com-login,                               \\
  password=my-easydns.com-password                          \\
  my-toplevel-domain.com,my-other-domain.com
EoEXAMPLE
}
######################################################################
## nic_easydns_update
######################################################################
sub nic_easydns_update {
    debug("\nnic_easydns_update -------------------");

    ## group hosts with identical attributes together 
    ## my %groups = group_hosts_by([ @_ ], [ qw(login password server wildcard mx backupmx) ]);

    ## each host is in a group by itself
    my %groups = map { $_ => [ $_ ] } @_;

    my %errors = (
       'NOACCESS' => 'Authentication failed. This happens if the username/password OR host or domain are wrong.',
       'NOSERVICE'=> 'Dynamic DNS is not turned on for this domain.',
       'ILLEGAL'  => 'Client sent data that is not allowed in a dynamic DNS update.',
       'TOOSOON'  => 'Update frequency is too short.',
    );

    ## update each set of hosts that had similar configurations
    foreach my $sig (keys %groups) {
    	my @hosts = @{$groups{$sig}};
    	my $hosts = join(',', @hosts);
    	my $h     = $hosts[0];
	my $ip    = $config{$h}{'wantip'};
	delete $config{$_}{'wantip'} foreach @hosts;

	info("setting IP address to %s for %s", $ip, $hosts);
	verbose("UPDATE:","updating %s", $hosts);

	#'http://members.easydns.com/dyn/dyndns.php?hostname=test.burry.ca&myip=10.20.30.40&wildcard=ON'

	my $url;
	$url   = "http://$config{$h}{'server'}/dyn/dyndns.php?";
	$url  .= "hostname=$hosts";
	$url  .= "&myip=";
	$url  .= $ip            if $ip;
	$url  .= "&wildcard=" . ynu($config{$h}{'wildcard'}, 'ON', 'OFF', 'OFF') if defined $config{$h}{'wildcard'};

	if ($config{$h}{'mx'}) {
	    $url .= "&mx=$config{$h}{'mx'}";
	    $url .= "&backmx=" . ynu($config{$h}{'backupmx'}, 'YES', 'NO');
	}

	my $reply = geturl(opt('proxy'), $url, $config{$h}{'login'}, $config{$h}{'password'});
	if (!defined($reply) || !$reply) {
	    failed("updating %s: Could not connect to %s.", $hosts, $config{$h}{'server'});
	    last;
	}
	last if !header_ok($hosts, $reply);
	
	my @reply = split /\n/, $reply;
	my $state = 'header';
	foreach my $line (@reply) {
	    if ($state eq 'header') {
		$state = 'body';
	    
	    } elsif ($state eq 'body') {
		$state = 'results' if $line eq '';
	    
	    } elsif ($state =~ /^results/) {
		$state = 'results2';

		my ($status) = $line =~ /^(\S*)\b.*/;
		my $h = shift @hosts;
	    
		$config{$h}{'status'} = $status;
		if ($status eq 'NOERROR') {
		    $config{$h}{'ip'}     = $ip;
		    $config{$h}{'mtime'}  = $now;
		    success("updating %s: %s: IP address set to %s", $h, $status, $ip);
		
		} elsif ($status =~ /TOOSOON/) {
		    ## make sure we wait at least a little
		    my ($wait, $units) = (5, 'm');
		    my ($sec,  $scale) = ($wait, 1);
		
		    ($scale, $units) = (1, 'seconds')   if $units eq 's';
		    ($scale, $units) = (60, 'minutes')  if $units eq 'm';
		    ($scale, $units) = (60*60, 'hours') if $units eq 'h';
		    $config{$h}{'wtime'} = $now + $sec;
		    warning("updating %s: %s: wait $wait $units before further updates", $h, $status, $ip);
		
		} elsif (exists $errors{$status}) {
		    failed("updating %s: %s: %s", $h, $line, $errors{$status});

		} else {
		    failed("updating %s: %s: unexpected status (%s)", $h, $line);
		} 	
		last;
	    }
	}
	failed("updating %s: Could not connect to %s.", $hosts, $config{$h}{'server'})
	    if $state ne 'results2';
    }
}	
######################################################################

######################################################################
## nic_dnspark_updateable
######################################################################
sub nic_dnspark_updateable {
    my $host   = shift;
    my $update = 0;

    if ($config{$host}{'mx'} ne $cache{$host}{'mx'}) {
	info("forcing updating %s because 'mx' has changed to %s.", $host, $config{$host}{'mx'});
	$update = 1;

    } elsif ($config{$host}{'mx'} && ($config{$host}{'mxpri'} ne $cache{$host}{'mxpri'})) {
	info("forcing updating %s because 'mxpri' has changed to %s.", $host, $config{$host}{'mxpri'});
	$update = 1;
    }
    return $update;
}
######################################################################
## nic_dnspark_examples
######################################################################
sub nic_dnspark_examples {
    return <<EoEXAMPLE;
o 'dnspark'

The 'dnspark' protocol is used by DNS service offered by www.dnspark.com.

Configuration variables applicable to the 'dnspark' protocol are:
  protocol=dnspark             ## 
  server=fqdn.of.service       ## defaults to www.dnspark.com
  backupmx=no|yes              ## indicates that DNSPark should be the secondary MX 
                               ## for this domain or host.
  mx=any.host.domain           ## a host MX'ing for this host or domain.
  mxpri=priority               ## MX priority.
  login=service-login          ## login name and password  registered with the service
  password=service-password    ##
  fully.qualified.host         ## the host registered with the service.

Example ${program}.conf file entries:
  ## single host update
  protocol=dnspark,                                         \\
  login=my-dnspark.com-login,                               \\
  password=my-dnspark.com-password                          \\
  myhost.dnspark.com 

  ## multiple host update with wildcard'ing mx, and backupmx
  protocol=dnspark,                                         \\
  login=my-dnspark.com-login,                               \\
  password=my-dnspark.com-password,                         \\
  mx=a.host.willing.to.mx.for.me,                           \\
  mxpri=10, 	                                            \\
  my-toplevel-domain.com,my-other-domain.com

  ## multiple host update to the custom DNS service
  protocol=dnspark,                                         \\
  login=my-dnspark.com-login,                               \\
  password=my-dnspark.com-password                          \\
  my-toplevel-domain.com,my-other-domain.com
EoEXAMPLE
}
######################################################################
## nic_dnspark_update
######################################################################
sub nic_dnspark_update {
    debug("\nnic_dnspark_update -------------------");

    ## group hosts with identical attributes together 
    ## my %groups = group_hosts_by([ @_ ], [ qw(login password server wildcard mx backupmx) ]);

    ## each host is in a group by itself
    my %groups = map { $_ => [ $_ ] } @_;

    my %errors = (
       'nochange' => 'No changes made to the hostname(s). Continual updates with no changes lead to blocked clients.',
       'nofqdn' => 'No valid FQDN (fully qualified domain name) was specified',
       'nohost'=> 'An invalid hostname was specified. This due to the fact the hostname has not been created in the system. Creating new host names via clients is not supported.',
       'abuse'  => 'The hostname specified has been blocked for abuse.',
       'unauth'  => 'The username specified is not authorized to update this hostname and domain.',
       'blocked'  => 'The dynamic update client (specified by the user-agent) has been blocked from the system.',
       'notdyn'  => 'The hostname specified has not been marked as a dynamic host. Hosts must be marked as dynamic in the system in order to be updated via clients. This prevents unwanted or accidental updates.',
    );

    ## update each set of hosts that had similar configurations
    foreach my $sig (keys %groups) {
    	my @hosts = @{$groups{$sig}};
    	my $hosts = join(',', @hosts);
    	my $h     = $hosts[0];
	my $ip    = $config{$h}{'wantip'};
	delete $config{$_}{'wantip'} foreach @hosts;

	info("setting IP address to %s for %s", $ip, $hosts);
	verbose("UPDATE:","updating %s", $hosts);

	#'http://www.dnspark.com:80/visitors/update.html?myip=10.20.30.40&hostname=test.burry.ca'

	my $url;
	$url   = "http://$config{$h}{'server'}/visitors/update.html";
	$url  .= "?hostname=$hosts";
	$url  .= "&myip=";
	$url  .= $ip            if $ip;

	if ($config{$h}{'mx'}) {
	    $url .= "&mx=$config{$h}{'mx'}";
	    $url .= "&mxpri=" . $config{$h}{'mxpri'};
	}

	my $reply = geturl(opt('proxy'), $url, $config{$h}{'login'}, $config{$h}{'password'});
	if (!defined($reply) || !$reply) {
	    failed("updating %s: Could not connect to %s.", $hosts, $config{$h}{'server'});
	    last;
	}
	last if !header_ok($hosts, $reply);
	
	my @reply = split /\n/, $reply;
	my $state = 'header';
	foreach my $line (@reply) {
	    if ($state eq 'header') {
		$state = 'body';
	    
	    } elsif ($state eq 'body') {
		$state = 'results' if $line eq '';
	    
	    } elsif ($state =~ /^results/) {
		$state = 'results2';

		my ($status) = $line =~ /^(\S*)\b.*/;
		my $h = pop @hosts;
	    
		$config{$h}{'status'} = $status;
		if ($status eq 'ok') {
		    $config{$h}{'ip'}     = $ip;
		    $config{$h}{'mtime'}  = $now;
		    success("updating %s: %s: IP address set to %s", $h, $status, $ip);
		
		} elsif ($status =~ /TOOSOON/) {
		    ## make sure we wait at least a little
		    my ($wait, $units) = (5, 'm');
		    my ($sec,  $scale) = ($wait, 1);
		
		    ($scale, $units) = (1, 'seconds')   if $units eq 's';
		    ($scale, $units) = (60, 'minutes')  if $units eq 'm';
		    ($scale, $units) = (60*60, 'hours') if $units eq 'h';
		    $config{$h}{'wtime'} = $now + $sec;
		    warning("updating %s: %s: wait $wait $units before further updates", $h, $status, $ip);
		
		} elsif (exists $errors{$status}) {
		    failed("updating %s: %s: %s", $h, $line, $errors{$status});

		} else {
		    failed("updating %s: %s: unexpected status (%s)", $h, $line);
		} 	
		last;
	    }
	}
	failed("updating %s: Could not connect to %s.", $hosts, $config{$h}{'server'})
	    if $state ne 'results2';
    }
}	

######################################################################

######################################################################
## nic_namecheap_examples
######################################################################
sub nic_namecheap_examples {
    return <<EoEXAMPLE;

o 'namecheap'

The 'namecheap' protocol is used by DNS service offered by www.namecheap.com.

Configuration variables applicable to the 'namecheap' protocol are:
  protocol=namecheap           ## 
  server=fqdn.of.service       ## defaults to dynamicdns.park-your-domain.com
  login=service-login          ## login name and password  registered with the service
  password=service-password    ##
  fully.qualified.host         ## the host registered with the service.

Example ${program}.conf file entries:
  ## single host update
  protocol=namecheap,                                         \\
  login=my-namecheap.com-login,                               \\
  password=my-namecheap.com-password                          \\
  myhost.namecheap.com 

EoEXAMPLE
}
######################################################################
## nic_namecheap_update
##
## written by Dan Boardman
##
## based on http://www.namecheap.com/resources/help/index.asp?t=dynamicdns
## needs this url to update:
## http://dynamicdns.park-your-domain.com/update?host=host_name&
## domain=domain.com&password=domain_password[&ip=your_ip]
##
######################################################################
sub nic_namecheap_update {


    debug("\nnic_namecheap1_update -------------------");

    ## update each configured host
    foreach my $h (@_) {
	my $ip = delete $config{$h}{'wantip'};
        info("setting IP address to %s for %s", $ip, $h);
        verbose("UPDATE:","updating %s", $h);

        my $url;
        $url   = "http://$config{$h}{'server'}/update";
        $url  .= "?host=$h";
        $url  .= "&domain=$config{$h}{'login'}";
        $url  .= "&password=$config{$h}{'password'}";
        $url  .= "&ip=";
        $url  .= $ip if $ip;

        my $reply = geturl(opt('proxy'), $url);
        if (!defined($reply) || !$reply) {
            failed("updating %s: Could not connect to %s.", $h, $config{$h}{'server'});
            last;
        }
        last if !header_ok($h, $reply);

        my @reply = split /\n/, $reply;
        if (grep /<ErrCount>0/i, @reply) {
            $config{$h}{'ip'}     = $ip;
            $config{$h}{'mtime'}  = $now;
            $config{$h}{'status'} = 'good';
            success("updating %s: good: IP address set to %s", $h, $ip);
        } else {
            $config{$h}{'status'} = 'failed';
            warning("SENT:    %s", $url) unless opt('verbose');
            warning("REPLIED: %s", $reply);
            failed("updating %s: Invalid reply.", $h);
        }
    }
}

######################################################################


######################################################################

######################################################################
## nic_sitelutions_examples
######################################################################
sub nic_sitelutions_examples {
    return <<EoEXAMPLE;

o 'sitelutions'

The 'sitelutions' protocol is used by DNS services offered by www.sitelutions.com.

Configuration variables applicable to the 'sitelutions' protocol are:
  protocol=sitelutions         ## 
  server=fqdn.of.service       ## defaults to sitelutions.com
  login=service-login          ## login name and password  registered with the service
  password=service-password    ##
  A_record_id                  ## Id of the A record for the host registered with the service.

Example ${program}.conf file entries:
  ## single host update
  protocol=sitelutions,                                         \\
  login=my-sitelutions.com-login,                               \\
  password=my-sitelutions.com-password                          \\
  my-sitelutions.com-id_of_A_record

EoEXAMPLE
}
######################################################################
## nic_sitelutions_update
##
## written by Mike W. Smith
##
## based on http://www.sitelutions.com/help/dynamic_dns_clients#updatespec
## needs this url to update:
## https://www.sitelutions.com/dnsup?id=990331&user=myemail@mydomain.com&pass=SecretPass&ip=192.168.10.4
## domain=domain.com&password=domain_password&ip=your_ip
##
######################################################################
sub nic_sitelutions_update {


    debug("\nnic_sitelutions_update -------------------");

    ## update each configured host
    foreach my $h (@_) {
	my $ip = delete $config{$h}{'wantip'};
        info("setting IP address to %s for %s", $ip, $h);
        verbose("UPDATE:","updating %s", $h);

        my $url;
        $url   = "http://$config{$h}{'server'}/dnsup";
        $url  .= "?id=$h";
        $url  .= "&user=$config{$h}{'login'}";
        $url  .= "&pass=$config{$h}{'password'}";
        $url  .= "&ip=";
        $url  .= $ip if $ip;

        my $reply = geturl(opt('proxy'), $url);
        if (!defined($reply) || !$reply) {
            failed("updating %s: Could not connect to %s.", $h, $config{$h}{'server'});
            last;
        }
        last if !header_ok($h, $reply);

        my @reply = split /\n/, $reply;
        if (grep /success/i, @reply) {
            $config{$h}{'ip'}     = $ip;
            $config{$h}{'mtime'}  = $now;
            $config{$h}{'status'} = 'good';
            success("updating %s: good: IP address set to %s", $h, $ip);
        } else {
            $config{$h}{'status'} = 'failed';
            warning("SENT:    %s", $url) unless opt('verbose');
            warning("REPLIED: %s", $reply);
            failed("updating %s: Invalid reply.", $h);
        }
    }
}

###################################################################### 

###################################################################### 
## nic_freedns_examples 
###################################################################### 
sub nic_freedns_examples {
return <<EoEXAMPLE;

o 'freedns'

The 'freedns' protocol is used by DNS services offered by freedns.afraid.org.

Configuration variables applicable to the 'freedns' protocol are:
  protocol=freedns             ##
  server=fqdn.of.service       ## defaults to freedns.afraid.org
  login=service-login          ## login name and password registered with the service
  password=service-password    ##
  fully.qualified.host         ## the host registered with the service.

Example ${program}.conf file entries:
  ## single host update
  protocol=freedns,                                             \\
  login=my-freedns.afraid.org-login,                            \\
  password=my-freedns.afraid.org-password                       \\
  myhost.afraid.com

EoEXAMPLE
} 
######################################################################
## nic_freedns_update
##
## written by John Haney
##
## based on http://freedns.afraid.org/api/
## needs this url to update:
## http://freedns.afraid.org/api/?action=getdyndns&sha=<sha1sum of login|password>
## This returns a list of host|currentIP|updateURL lines.
## Pick the line that matches myhost, and fetch the URL.
## word 'Updated' for success, 'fail' for failure.
##
######################################################################
sub nic_freedns_update {


    debug("\nnic_freedns_update -------------------");

    ## First get the list of updatable hosts
    my $url;
    $url = "http://$config{$_[0]}{'server'}/api/?action=getdyndns&sha=".&sha1_hex("$config{$_[0]}{'login'}|$config{$_[0]}{'password'}");
    my $reply = geturl(opt('proxy'), $url);
    if (!defined($reply) || !$reply || !header_ok($_[0], $reply)) {
        failed("updating %s: Could not connect to %s for site list.", $_[0], $url);
	return;
    }
    my @lines = split("\n", $reply);
    my %freedns_hosts;
    grep {
        my @rec = split(/\|/, $_);
	$freedns_hosts{$rec[0]} = \@rec if ($#rec > 0);
    } @lines;
    if (!keys %freedns_hosts) {
	failed("Could not get freedns update URLs from %s", $config{$_[0]}{'server'});
	return;
    }
    ## update each configured host
    foreach my $h (@_) {
        if(!$h){ next };
        my $ip = delete $config{$h}{'wantip'};
	info("setting IP address to %s for %s", $ip, $h);
	verbose("UPDATE:","updating %s", $h);

	if($ip eq $freedns_hosts{$h}->[1]) { 
	    $config{$h}{'ip'}     = $ip; 
	    $config{$h}{'mtime'}  = $now; 
	    $config{$h}{'status'} = 'good'; 
	    success("update not necessary %s: good: IP address already set to %s", $h, $ip); 
	} else {
	    my $reply = geturl(opt('proxy'), $freedns_hosts{$h}->[2]);
	    if (!defined($reply) || !$reply) {
	        failed("updating %s: Could not connect to %s.", $h, $freedns_hosts{$h}->[2]);
		last;
	    }
	    if(!header_ok($h, $reply)) { 
		$config{$h}{'status'} = 'failed'; 
		last; 
	    }

	    if($reply =~ /Updated.*$h.*to.*$ip/) { 
		$config{$h}{'ip'}     = $ip; 
		$config{$h}{'mtime'}  = $now; 
		$config{$h}{'status'} = 'good'; 
		success("updating %s: good: IP address set to %s", $h, $ip); 
	    } else {
	        $config{$h}{'status'} = 'failed';
		warning("SENT: %s", $freedns_hosts{$h}->[2]) unless opt('verbose');
		warning("REPLIED: %s", $reply);
		failed("updating %s: Invalid reply.", $h);
	    }
	}
    }
}

###################################################################### 
## nic_changeip_examples 
###################################################################### 
sub nic_changeip_examples {
return <<EoEXAMPLE;

o 'changeip'

The 'changeip' protocol is used by DNS services offered by changeip.com.

Configuration variables applicable to the 'changeip' protocol are:
  protocol=changeip            ##
  server=fqdn.of.service       ## defaults to nic.changeip.com
  login=service-login          ## login name and password registered with the service
  password=service-password    ##
  fully.qualified.host         ## the host registered with the service.

Example ${program}.conf file entries:
  ## single host update
  protocol=changeip,                                               \\
  login=my-my-changeip.com-login,                                  \\
  password=my-changeip.com-password                                \\
  myhost.changeip.org

EoEXAMPLE
} 

######################################################################
## nic_changeip_update
##
## adapted by Michele Giorato
##
## https://nic.ChangeIP.com/nic/update?hostname=host.example.org&myip=66.185.162.19
##
######################################################################
sub nic_changeip_update {


    debug("\nnic_changeip_update -------------------");

    ## update each configured host
    foreach my $h (@_) {
	my $ip = delete $config{$h}{'wantip'};
        info("setting IP address to %s for %s", $ip, $h);
        verbose("UPDATE:","updating %s", $h);

        my $url;
        $url   = "http://$config{$h}{'server'}/nic/update";
        $url  .= "?hostname=$h";
        $url  .= "&ip=";
        $url  .= $ip if $ip;

		my $reply = geturl(opt('proxy'), $url, $config{$h}{'login'}, $config{$h}{'password'});
        if (!defined($reply) || !$reply) {
            failed("updating %s: Could not connect to %s.", $h, $config{$h}{'server'});
            last;
        }
        last if !header_ok($h, $reply);

        my @reply = split /\n/, $reply;
        if (grep /success/i, @reply) {
            $config{$h}{'ip'}     = $ip;
            $config{$h}{'mtime'}  = $now;
            $config{$h}{'status'} = 'good';
            success("updating %s: good: IP address set to %s", $h, $ip);
        } else {
            $config{$h}{'status'} = 'failed';
            warning("SENT:    %s", $url) unless opt('verbose');
            warning("REPLIED: %s", $reply);
            failed("updating %s: Invalid reply.", $h);
        }
    }
}

######################################################################
## nic_dtdns_examples
######################################################################
sub nic_dtdns_examples {
    return <<EoEXAMPLE; 
o 'dtdns'
                          
The 'dtdns' protocol is the protocol used by the dynamic hostname services
of the 'DtDNS' dns services. This is currently used by the free
dynamic DNS service offered by www.dtdns.com.
    
Configuration variables applicable to the 'dtdns' protocol are:
  protocol=dtdns               ## 
  server=www.fqdn.of.service   ## defaults to www.dtdns.com
  password=service-password    ## password registered with the service
  client=name_of_updater       ## defaults to $program (10 chars max, no spaces)
  fully.qualified.host         ## the host registered with the service.
                        
Example ${program}.conf file entries:
  ## single host update
  protocol=dtdns,                                       \\
  password=my-dydns.za.net-password,                    \\
  client=ddclient                                       \\
  myhost.dtdns.net
                        
EoEXAMPLE
}

######################################################################
## nic_dtdns_update
## by Achim Franke
######################################################################
sub nic_dtdns_update {
    debug("\nnic_dtdns_update -------------------");

    ## update each configured host
    foreach my $h (@_) {
	my $ip = delete $config{$h}{'wantip'};
        info("setting IP address to %s for %s", $ip, $h);
        verbose("UPDATE:","updating %s", $h);

        # Set the URL that we're going to to update
        my $url;
        $url  = "http://$config{$h}{'server'}/api/autodns.cfm";
        $url .= "?id=";
        $url .= $h;
        $url .= "&pw=";
        $url .= $config{$h}{'password'};
        $url .= "&ip=";
        $url .= $ip;
        $url .= "&client=";
        $url .= $config{$h}{'client'};

        # Try to get URL
        my $reply = geturl(opt('proxy'), $url);

        # No response, declare as failed
        if (!defined($reply) || !$reply) {
            failed("updating %s: Could not connect to %s.", $h, $config{$h}{'server'});
            last;
        }
        last if !header_ok($h, $reply);

        # Response found, just declare as success (this is ugly, we need more error checking)
        if ($reply =~ /now\spoints\sto/)
        {
                $config{$h}{'ip'}     = $ip;
                $config{$h}{'mtime'}  = $now;
                $config{$h}{'status'} = 'good';
                success("updating %s: good: IP address set to %s", $h, $ip);
         }
         else
         {
                my @reply = split /\n/, $reply;
                my $returned = pop(@reply);
                $config{$h}{'status'} = 'failed';
                failed("updating %s: Server said: '$returned'", $h);
         }
    }
}

######################################################################
# vim: ai ts=4 sw=4 tw=78 :


__END__
