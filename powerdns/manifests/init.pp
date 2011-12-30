# Author: Kumina bv <support@kumina.nl>

# Puppet manifest for PowerDNS
#
# Copyright (c) 2009 by Kees Meijs <kees@kumina.nl> for Kumina bv.
#
# This work is licensed under the Creative Commons Attribution-Share Alike 3.0
# Unported license. In short: you are free to share and to make derivatives of
# this work under the conditions that you appropriately attribute it, and that
# you only distribute it under the same, similar or a compatible license. Any
# of the above conditions can be waived if you get permission from the copyright
# holder.
#
# This manifest was tested on Debian GNU/Linux 4.0 (etch).

# Class: powerdns::common
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class powerdns::common {
  # Make sure directories have correct permissions.
  file {
    "/var/lib/powerdns":
      ensure => directory,
      owner => "pdns",
      group => "root",
      mode => 750,
      require => Package["pdns-server"];
    "/etc/powerdns/pdns.d":
      ensure => directory,
      owner => "root",
      group => "root",
      mode => "750",
      require => Package["pdns-server"];
    }

  file {
    "/etc/powerdns/pdns.conf":
      content => template("powerdns/powerdns/pdns.conf.erb"),
      owner => "root",
      group => "root",
      mode => 640,
      notify => Service["pdns"],
      require => Package["pdns-server"];
    "/etc/powerdns/pdns.d/pdns.local":
      owner => "root",
      group => "root",
      mode => 640,
      notify => Service["pdns"],
      require => Package["pdns-server"];
  }

  # Make sure PowerDNS is running.
  service {
    "pdns":
      ensure => running,
      hasrestart => true,
      pattern => "pdns_server",
      require => File["/etc/powerdns/pdns.conf"];
  }
}

# Class: powerdns::master
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class powerdns::master inherits powerdns::common {
  # Install needed packages.
  package {
    "pdns-server":
      ensure => installed;
    "pdns-backend-mysql":
      ensure => installed;
  }

  File["/etc/powerdns/pdns.d/pdns.local"] {
    content => template("powerdns/powerdns/pdns.d/pdns.local-master.erb"),
  }
}

# Class: powerdns::slave
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class powerdns::slave inherits powerdns::common {
  # Install needed packages.
  package {
    "pdns-server":
      ensure => installed;
    "pdns-backend-sqlite":
      ensure => installed;
  }

  File["/etc/powerdns/pdns.d/pdns.local"] {
    source => "puppet://puppet/powerdns/powerdns/pdns.d/pdns.local-slave",
  }
}

# Class: powerdns::recursor
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class powerdns::recursor {
  # Install needed packages.
  package {
    "pdns-recursor":
      ensure => installed;
  }

  # Make sure PowerDNS recursor is running.
  service {
    "pdns-recursor":
      ensure => running,
      hasrestart => true,
      pattern => "pdns_recursor",
      require => File["/etc/powerdns/recursor.conf"];
  }

  file {
    "/etc/powerdns/recursor.conf":
      content => template("powerdns/powerdns/recursor.conf.erb"),
      owner => "root",
      group => "root",
      mode => 640,
      notify => Service["pdns-recursor"],
      require => Package["pdns-recursor"];
  }
}
