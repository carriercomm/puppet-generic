class nagios::server {
	include nagios::plugins

	define check($command) {
		nagios_command { "check_$name":
			command_line => $command,
			target => "/etc/nagios-plugins/config/$name.cfg",
			notify => Exec["reload-nagios3"],
			require => Package["nagios-plugins-basic"],
		}
	}

	package { ["nagios3", "nagios-plugins", "curl", "nagios-nrpe-plugin"]:
		ensure => installed,
	}

	service { "nagios3":
		ensure => running,
		hasrestart => true,
		require => Package["nagios3"];
	}

	exec { "reload-nagios3":
		command     => "/etc/init.d/nagios3 reload",
		refreshonly => true,
	}

	# Change the homedir for Nagios to /var/lib/nagios3 so we can put e.g.
	# a .mycnf with MySQL login details in there.
	user { "nagios":
		home => "/var/lib/nagios3",
		require => Package["nagios3"],
	}

	kfile {
		"/etc/default/nagios3":
			source => "nagios/default/nagios3",
			require => Package["nagios3"];
		"/etc/nagios3/send_sms.cfg":
			group => "nagios",
			mode => 640,
			source => "nagios/send_sms/send_sms.cfg",
			require => Package["nagios3"];
		"/usr/local/bin/send_sms":
			group => "nagios",
			mode => 755,
			source => "nagios/send_sms/send_sms",
			require => [File["/etc/nagios3/send_sms.cfg"], Package["curl"]];
	}

	# Allow external commands to be submitted through the web interface
	kfile {
		"/var/lib/nagios3":
			mode  => 710,
			owner => 'nagios',
			group => "www-data";
		"/var/lib/nagios3/rw":
			group => "www-data",
			owner => 'nagios',
			mode  => 2710;
	}
}

class nagios::server::plugins {
	include nagios::plugins

	# Check for a weak SSH host key. See
	# http://lists.debian.org/debian-security-announce/2008/msg00152.html
	check { "weak_ssh_host_key":
		command => '/usr/local/lib/nagios/plugins/check_weak_ssh_host_key $HOSTADDRESS$',
		require => File["/usr/local/lib/nagios/plugins/check_weak_ssh_host_key"],
	}

	kfile {
		"/usr/local/lib/nagios/plugins/check_weak_ssh_host_key":
			source => "nagios/plugins/check_weak_ssh_host_key",
			group => "staff",
			mode => 755,
			require => [File["/usr/local/bin/dowkd.pl"],
				    File["/var/cache/dowkd"],
				    File["/usr/local/lib/nagios/plugins"]];
		"/var/cache/dowkd":
			ensure => directory,
			owner => "nagios",
			require => Package["nagios-nrpe-server"],
			mode => 775;
		"/usr/local/bin/dowkd.pl":
			source => "nagios/bin/dowkd.pl",
			mode => 755;
	}

	check { "disk_smb_fixed":
		command => '/usr/local/lib/nagios/plugins/check_disk_smb_fixed -H $HOSTADDRESS$ -w 95 -c 99 -s $ARG1$',
		require => File["/usr/local/lib/nagios/plugins/check_disk_smb_fixed"];
	}

	kfile { "/usr/local/lib/nagios/plugins/check_disk_smb_fixed":
		source => "nagios/plugins/check_disk_smb_fixed",
		group => "staff",
		mode => 755,
		require => File["/usr/local/lib/nagios/plugins"];
	}

	# This one is a reversed age check. Warns when a file is young.
	kfile { "/usr/local/lib/nagios/plugins/check_file_age_reversed":
		source => "nagios/plugins/check_file_age_reversed",
		group => "staff",
		mode => 755,
		require => File["/usr/local/lib/nagios/plugins"];
	}
}
