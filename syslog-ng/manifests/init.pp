# Author: Kumina bv <support@kumina.nl>

# Class: syslog-ng::common
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class syslog-ng::common {
  package { "syslog-ng":
    ensure => installed,
  }

  service { "syslog-ng":
    subscribe => File["/etc/syslog-ng/syslog-ng.conf"],
    enable => true,
    ensure => running,
  }
}

# Class: syslog-ng::client
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class syslog-ng::client {
  include syslog-ng::common

  file { "/etc/syslog-ng/syslog-ng.conf":
    content => template("syslog-ng/client/syslog-ng.conf"),
    mode => 644,
    owner => "root",
    group => "root",
    require => Package["syslog-ng"];
  }
}

# Class: syslog-ng::server
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class syslog-ng::server {
  include syslog-ng::common

  file { "/etc/syslog-ng/syslog-ng.conf":
    source => "puppet://puppet/syslog-ng/server/syslog-ng.conf",
    mode => 644,
    owner => "root",
    group => "root",
    require => Package["syslog-ng"];
  }
}
