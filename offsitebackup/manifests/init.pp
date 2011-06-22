class offsitebackup::common {
	define line($file, $line, $ensure = 'present') {
		case $ensure {
			default: {
				err("unknown ensure value ${ensure}")
			}
			present: {
				exec { "/bin/echo '${line}' >> '${file}'":
					unless => "/bin/grep -Fx '${line}' '${file}'"
				}
			}
			absent: {
				exec { "/usr/bin/perl -ni -e 'print unless /^\\Q${line}\\E\$/' '${file}'":
					onlyif => "/bin/grep -Fx '${line}' '${file}'"
				}
			}
		}
	}

	define backupkey($backupserver, $backuproot=$backup_home, $user, $key) {
		$backupdir = "$backuproot/$name"
		$line = "command=\"rdiff-backup --server --restrict $backupdir\",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding ssh-rsa $key Backup key for $name"

		line { "add-key-${name}":
			ensure  => "present",
			file    => "${backuproot}/.ssh/authorized_keys",
			line    => $line,
			require => [User[$user], File["${backuproot}/.ssh"]],
		}
	}

	define backupuser($home=$backup_home, $comment="") {
		user { "$name":
			ensure => present,
			home => $home,
			membership => minimum,
			shell => "/bin/bash",
			comment => $comment,
		}

		file { "$home":
			ensure => directory,
			mode => 750,
			owner => $name,
			group => "backup",
			require => User["$name"],
		}

		file { "$home/.ssh":
			ensure => directory,
			mode => 700,
			owner => $name,
			group => "users",
			require => File["$home"],
		}

		file { "$home/.ssh/authorized_keys":
			ensure => file,
			mode => 644,
			owner => $name,
			group => "users",
			require => File["$home/.ssh"],
		}
	}
}

class offsitebackup::client {
	kpackage { ["offsite-backup","backup-scripts"]:
		ensure => latest;
	}

	@@offsitebackup::common::backupkey { "$fqdn":
		backupserver => $backup_server,
		backuproot => $backup_home,
		user => $backup_user,
		key => $backupsshkey,
		require => Package["offsite-backup"],
	}

	$backup_rm_older_than = $backup_remove_older_than ? {
		undef => "30B",
		default => $backup_remove_older_than,
	}

	file { "/etc/backup/offsite-backup.conf":
		content => template("offsitebackup/client/offsite-backup.conf"),
		require => Package["offsite-backup"];
	}

	file { "/etc/backup/prepare.d/dpkg-list":
		ensure => symlink,
		target => "/usr/share/offsite-backup/prepare/dpkg-list",
		require => Package["offsite-backup"];
	}

	file { "/etc/backup/prepare.d/filesystems":
		ensure => symlink,
		target => "/usr/share/offsite-backup/prepare/filesystems",
		require => Package["offsite-backup"];
	}
}

class offsitebackup::server {
	Offsitebackup::Common::Backupkey <<| backupserver == $fqdn |>>

	package { ["rdiff-backup", "python-pylibacl", "python-pyxattr"]:
		ensure => installed,
	}
}
