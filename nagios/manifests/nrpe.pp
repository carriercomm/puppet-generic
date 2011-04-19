class nagios::nrpe {
	include nagios::nrpe::plugins

	define check($command) {
		kfile { "/etc/nagios/nrpe.d/$name.cfg":
			content => "command[check_$name]=$command\n",
			require => File["/etc/nagios/nrpe.d"],
			notify => Service["nagios-nrpe-server"],
		}
	}

	kpackage { "nagios-nrpe-server":; }

	# We're starting NRPE from inetd, to allow it to use tcpwrappers for
	# access control.
	service { "nagios-nrpe-server":
		ensure     => stopped,
		pattern    => "/usr/sbin/nrpe",
		hasrestart => true,
		require    => Package["nagios-nrpe-server"],
	}

	kpackage { "openbsd-inetd":; }

	service { "openbsd-inetd":
		ensure => running,
		pattern => "/usr/sbin/inetd",
		require => Package["openbsd-inetd"],
	}

	exec { "update-services-add-nrpe":
		command => "/bin/echo 'nrpe\t\t5666/tcp\t\t\t# Nagios NRPE' >> /etc/services",
		unless => "/bin/grep -q ^nrpe /etc/services",
	}

	# Need to bind to the IP address for this host only, if this is a
	# vserver.  Otherwise, just listen on all IP addresses, to simplify the
	# Nagios configuration.
	exec { "update-inetd-add-nrpe":
		command => $virtual ? {
			vserver => "/usr/sbin/update-inetd --add '$ipaddress:nrpe stream tcp nowait nagios /usr/sbin/tcpd /usr/sbin/nrpe -c /etc/nagios/nrpe.cfg --inetd'",
			default => "/usr/sbin/update-inetd --add 'nrpe stream tcp nowait nagios /usr/sbin/tcpd /usr/sbin/nrpe -c /etc/nagios/nrpe.cfg --inetd'",
		},
		unless => $virtual ? {
		 	vserver => "/bin/grep -E -q '^#?\s*(<off>#)?\s*$ipaddress:nrpe /etc/inetd.conf",
		 	default => "/bin/grep -E -q '^#?\s*(<off>#)?\s*nrpe' /etc/inetd.conf",
		},
		require => [Service["nagios-nrpe-server"], Exec["update-services-add-nrpe"]],
		notify => Service["openbsd-inetd"],
	}

	exec { "update-inetd-enable-nrpe":
		command => virtual ? {
			vserver => "/usr/sbin/update-inetd --enable $ipaddress:nrpe",
			default => "/usr/sbin/update-inetd --enable nrpe",
		},
		unless => virtual ? {
			vserver => "/bin/grep -q ^$ipaddress:nrpe /etc/inetd.conf",
			default => "/bin/grep -q ^nrpe /etc/inetd.conf",
		},
		require => Exec["update-inetd-add-nrpe"],
		notify => Service["openbsd-inetd"],
	}

	exec { "/bin/echo 'nrpe: $nagios_nrpe_client' >> /etc/hosts.allow":
		unless => "/bin/grep -Fx 'nrpe: $nagios_nrpe_client' /etc/hosts.allow",
		require => Exec["update-inetd-enable-nrpe"],
	}

	kfile {
		"/etc/nagios/nrpe.cfg":
			source => ["puppet://puppet/nagios/nrpe/${lsbdistcodename}/nrpe.cfg",
			           "puppet://puppet/nagios/nrpe/nrpe.cfg"],
			require => Package["nagios-nrpe-server"];
		"/etc/nagios/nrpe.d":
			ensure => directory,
			require => Package["nagios-nrpe-server"];
	}
}

class nagios::nrpe::plugins {
	include nagios::plugins

	# Check DRBD replication health
	check {
		"drbd":
			command => '/usr/local/lib/nagios/plugins/check_drbd -d All',
			require => File["/usr/local/lib/nagios/plugins/check_drbd"];
		"drbd_primary":
			command => '/usr/local/lib/nagios/plugins/check_drbd -d All -r Primary',
			require => File["/usr/local/lib/nagios/plugins/check_drbd"];
		"drbd_secondary":
			command => '/usr/local/lib/nagios/plugins/check_drbd -d All -r Secondary',
			require => File["/usr/local/lib/nagios/plugins/check_drbd"];
	}

	# Check Pacemaker status
	check {
		"pacemaker":
			command => '/usr/bin/sudo /usr/sbin/crm_mon -s';
	}

	# TODO This should be done by kbp_monitoring::client::pacemaker
	include gen_sudo
	gen_sudo::rule { "pacemaker sudo rules":
		entity => "nagios",
		as_user => "root",
		command => "/usr/sbin/crm_mon -s",
		password_required => false;
	}

	# aMaVis checks
	check {
		"amavis_scanner":
			command => '/usr/lib/nagios/plugins/check_smtp -H 127.0.0.1 -p 10024',
			require => File["/etc/nagios/nrpe.d"];
		"amavis_mta":
			command => '/usr/lib/nagios/plugins/check_smtp -H 127.0.0.1 -p 10025',
			require => File["/etc/nagios/nrpe.d"];
		"local_smtp":
			command => '/usr/lib/nagios/plugins/check_smtp -H 127.0.0.1',
			require => File["/etc/nagios/nrpe.d"];
	}

	# Various checks
	check {
		"libvirtd":
			command => '/usr/lib/nagios/plugins/check_procs -c 1: -C libvirtd',
			require => File["/etc/nagios/nrpe.d"];
		"arpwatch":
			command => '/usr/lib/nagios/plugins/check_procs -c 1: -C arpwatch',
			require => File["/etc/nagios/nrpe.d"];
		"remote_ntp":
			command => '/usr/lib/nagios/plugins/check_ntp_time -H 0.debian.pool.ntp.org',
			require => File["/etc/nagios/nrpe.d"];
		"ntpd":
			command => '/usr/lib/nagios/plugins/check_procs -c 1: -C ntpd',
			require => File["/etc/nagios/nrpe.d"];
	}

	include gen_sudo
	gen_sudo::rule { "Nagios can run all plugins as root":
		entity => "nagios",
		as_user => "ALL",
		password_required => false,
		command => ["/usr/lib/nagios/plugins/", "/usr/local/lib/nagios/plugins/"];
	}

	if versioncmp($lsbdistrelease, "6.0") >= 0 { #squeeze or later
		check{
			"dhcpd":
				command => '/usr/lib/nagios/plugins/check_procs -c 1: -C dhcpd',
				require => File["/etc/nagios/nrpe.d"];
		}
	}
	
	if versioncmp($lsbdistrelease, "6.0") <  0 { # before squeeze
		check{
			"dhcpd":
				command => '/usr/lib/nagios/plugins/check_procs -c 1: -C dhcpd3',
				require => File["/etc/nagios/nrpe.d"];
		}
	}


	# SSL certificates
	check {
		"sslcert":
			command => 'sudo /usr/lib/nagios/plugins/check_sslcert -c 7 -w 30 $ARG1$',
			require => [File["/etc/nagios/nrpe.d"], Package["nagios-plugins-kumina"]];
	}

	kpackage { "nagios-plugins-kumina":
		ensure => latest;
	}

	check {
		"pacemaker_config":
			command => '/usr/local/lib/nagios/plugins/check_pacemaker_config',
			require => File["/usr/local/lib/nagios/plugins/check_pacemaker_config","/etc/nagios/nrpe.d"];
	}

	kfile {
		"/usr/local/lib/nagios/plugins/check_pacemaker_config":
			source => "nagios/plugins/check_pacemaker_config",
			group => "staff",
			mode => 775,
			require => File["/usr/local/lib/nagios/plugins"];
	}

	kfile { "/usr/local/lib/nagios/plugins/check_drbd":
		source => "nagios/plugins/check_drbd",
		group => "staff",
		mode => 755,
		require => File["/usr/local/lib/nagios/plugins"];
	}

	# Check puppetd freshness.
	check { "puppet_state_freshness":
		command => "/usr/lib/nagios/plugins/check_file_age -f /var/lib/puppet/state/state.yaml -w 14400 -c 21600",
	}

	# Check ClamAV socket file and update service.
	check {
		"clamav_daemon_socket":
			command => "/usr/lib/nagios/plugins/check_file_age -w 0 -c 0 -C 0 -f /var/run/clamav/clamd.ctl";
		"clamav_freshclam":
			command => "/usr/lib/nagios/plugins/check_procs -C freshclam -w 1:1 -c 1:10";
	}

	# Check software RAID arrays.
	check {
		"mdraid":
			command => "sudo /usr/local/lib/nagios/plugins/check_mdraid",
	}

	# Check STP network.
	check {
		"stp_bridges":
			command => "/usr/local/lib/nagios/plugins/check_stp_bridges.sh",
	}

	kfile { "/usr/local/lib/nagios/plugins/check_mdraid":
		source => "nagios/plugins/check_mdraid",
		group => "staff",
		mode => 755,
		require => File["/usr/local/lib/nagios/plugins"];
	}

	kfile { "/usr/local/lib/nagios/plugins/check_stp_bridges.sh":
		source => "nagios/plugins/check_stp_bridges.sh",
		group => "staff",
		mode => 755,
		require => File["/usr/local/lib/nagios/plugins"];
	}

	# Check 3Ware RAID arrays.
	check {
		"3ware":
			command => "sudo /usr/local/lib/nagios/plugins/check_3ware",
	}

	kfile { "/usr/local/lib/nagios/plugins/check_3ware":
		source => "nagios/plugins/check_3ware",
		group => "staff",
		mode => 755,
		require => File["/usr/local/lib/nagios/plugins"];
	}

	# Check Adaptec RAID arrays.
	check {
		"adaptec":
			command => "sudo /usr/local/lib/nagios/plugins/check_adaptec",
	}

	kfile { "/usr/local/lib/nagios/plugins/check_adaptec":
		source => "nagios/plugins/check_adaptec",
		group => "staff",
		mode => 755,
		require => File["/usr/local/lib/nagios/plugins"];
	}

	# Make sure the latest installed kernel is also the running kernel.
	# (To reminds us to reboot a server after a kernel upgrade.)
	check { "running_kernel":
		command => "/usr/local/lib/nagios/plugins/check_running_kernel",
		require => File["/usr/local/lib/nagios/plugins/check_running_kernel"],
	}

	kfile { "/usr/local/lib/nagios/plugins/check_running_kernel":
		source => "nagios/plugins/check_running_kernel",
		group => "staff",
		mode => 755,
		require => File["/usr/local/lib/nagios/plugins"];
	}

	# Check the status of the bonding interfaces
	check { "bonding":
		command => "/usr/local/lib/nagios/plugins/check_bonding",
		require => File["/usr/local/lib/nagios/plugins/check_bonding"],
	}

	# Check service status using /etc/init.d scripts.
	check { "status_init":
		command => "sudo /usr/local/lib/nagios/plugins/check_proc_status.sh \$ARG1\$",
		require => File["/usr/local/lib/nagios/plugins/check_proc_status.sh"],
	}

	# This check is so we have a dependency for the backup machine. It checks if
	# there are processes called 'rdiff-backup', which would indicate an ongoing
	# backup. The CPU and Load checks depend on this check, so they won't fire
	# if backups are in progress.
	check { "rdiff-backup":
		command => "/usr/lib/nagios/plugins/check_procs -C rdiff-backup -w 0",
	}

	kfile { "/usr/local/lib/nagios/plugins/check_bonding":
		source => "nagios/plugins/check_bonding",
		group => "staff",
		mode => 755,
		require => File["/usr/local/lib/nagios/plugins"];
	}

	kfile { "/usr/local/lib/nagios/plugins/check_proc_status.sh":
		source => "nagios/plugins/check_proc_status.sh",
		group => "staff",
		mode => 755,
		require => File["/usr/local/lib/nagios/plugins"];
	}
}
