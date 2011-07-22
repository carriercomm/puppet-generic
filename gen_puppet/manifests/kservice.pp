# Author: Kumina bv <support@kumina.nl>

# Define: kservice
#
# Parameters:
#	hasrestart
#		Defines if the service has a restart option
#	hasstatus
#		Defines if the service has a status option
#	ensure
#		Defines whether the service should be running or not
#	enable
#		Defines whether the service should be started at boot, defaults to true
#	package
#		If defined sets the package to install
#	pensure
#		The ensure for the kpackage
#	ssubscribe
#		Defines a file or directory to subscribe on, triggering a reload if it changed
#
# Actions:
#	Install a package, starts the service and creates a reload exec.
#
# Depends:
#	gen_puppet
#
define kservice ($ensure="running", $hasrestart=true, $hasstatus=true, $enable=true, $package=false, $pensure="present", $pattern=false, $ssubscribe=false) {
	$package_name = $package ? {
		false   => $name,
		default => $package,
	}

	kpackage { "${package_name}":
		ensure => $pensure; }

	service { "${name}":
		ensure     => $ensure ? {
			false   => undef,
			default => $ensure,
		},
		hasrestart => $hasrestart,
		hasstatus  => $hasstatus,
		enable     => $enable,
		pattern    => $pattern ? {
			false   => undef,
			default => $pattern,
		},
		subscribe  => $ssubscribe ? {
			false   => undef,
			default => $ssubscribe,
		},
		require    => Kpackage[$package_name];
	}

	if $lsbmajdistrelease < 6 {
		exec { "reload-${name}":
			command     => "/etc/init.d/${name} reload",
			refreshonly => true;
		}
	} else {
		exec { "reload-${name}":
			command     => "/usr/sbin/service ${name} reload",
			refreshonly => true;
		}
	}
}
