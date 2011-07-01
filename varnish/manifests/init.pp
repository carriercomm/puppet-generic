# Author: Kumina bv <support@kumina.nl>

# Class: varnish
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class varnish {
	package { "varnish":
		ensure => installed,
	}

	service { "varnish":
		ensure => running,
		require => Package["varnish"],
	}

	file { "/etc/default/varnish":
		owner => "root",
		group => "root",
		mode => 644,
		source => "puppet://puppet/varnish/default/varnish",
		notify => Service["varnish"],
	}
}
