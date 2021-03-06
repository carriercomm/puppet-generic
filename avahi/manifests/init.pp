# Author: Kumina bv <support@kumina.nl>

# Class: avahi::daemon
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class avahi::daemon {
  package { "avahi-daemon":; }

  service { "avahi-daemon":
    ensure => running,
    require => File["/etc/avahi/avahi-daemon.conf"],
    subscribe => File["/etc/avahi/avahi-daemon.conf"];
  }

  file { "/etc/avahi/avahi-daemon.conf":
    require => Package["avahi-daemon"];
  }
}
