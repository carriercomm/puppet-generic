# Author: Kumina bv <support@kumina.nl>

# Class: apache
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class apache {
   # Define an apache2 site. Place all site configs into
   # /etc/apache2/sites-available and en-/disable them with this type.
   define site ( $ensure = 'present', $priority = '' ) {
      $link = $name ? {
        'default' => "000-default",
        default => $name,
      }

      case $ensure {
         'present' : {
            exec { "/usr/sbin/a2ensite $name":
               unless => "/bin/sh -c '[ -L /etc/apache2/sites-enabled/$link ] && [ /etc/apache2/sites-enabled/$link -ef /etc/apache2/sites-available/$name ]'",
               notify => Exec["reload-apache2"],
               require => [Package["apache2"], File["/etc/apache2/sites-available/$name"]],
            }
         }
         'absent' : {
            exec { "/usr/sbin/a2dissite $name":
               onlyif => "/bin/sh -c '[ -L /etc/apache2/sites-enabled/$link ] && [ /etc/apache2/sites-enabled/$link -ef /etc/apache2/sites-available/$name ]'",
               notify => Exec["reload-apache2"],
            }
         }
         default: { err ( "Unknown ensure value: '$ensure'" ) }
      }
   }

   # The next define is for creating virtual hosts that only forward to another site/page
   define forward_vhost ($ensure = present, $forward, $serveralias = false) {
           apache::site_config { $name:
                   template     => "apache/sites-available/simple.erb",
                   serveralias => $serveralias,
                   documentroot => "/var/www/",
           }

           apache::site { $name:
                   ensure => $ensure,
           }

           file { "/etc/apache2/vhost-additions/$name/redirect.conf":
                   ensure => $ensure,
                   content => "RewriteEngine on\nRewriteRule ^/* $forward [R=301]\n",
           }
   }

   # Define an apache2 module. Debian packages place the module config
   # into /etc/apache2/mods-available.
   define module ( $ensure = 'present' ) {
      case $ensure {
         'present' : {
            exec { "/usr/sbin/a2enmod $name":
               unless => "/bin/sh -c '[ -L /etc/apache2/mods-enabled/$name.load ] && [ /etc/apache2/mods-enabled/$name.load -ef /etc/apache2/mods-available/$name.load ]'",
               notify => Exec["force-reload-apache2"],
               require => Package["apache2"],
            }
         }
         'absent': {
            exec { "/usr/sbin/a2dismod $name":
               onlyif => "/bin/sh -c '[ -L /etc/apache2/mods-enabled/$name.load ] && [ /etc/apache2/mods-enabled/$name.load -ef /etc/apache2/mods-available/$name.load ]'",
               notify => Exec["force-reload-apache2"],
               require => Package["apache2"],
            }
         }
         default: { err ( "Unknown ensure value: '$ensure'" ) }
      }
   }

	# Mitigation for CVE-2011-3192, can be removed when patched
	# TODO remove this puppet resource after september first
	include apache::headers
	kfile { "/etc/apache2/conf.d/cve-2011-3192.conf":
		ensure  => absent,
		content => "# Drop the Range header when more than 5 ranges.\n# CVE-2011-3192\nSetEnvIf Range (,.*?){5,} bad-range=1\nRequestHeader unset Range env=bad-range\n# optional logging.\nCustomLog /var/log/apache2/range-CVE-2011-3192.log common env=bad-range",
		notify  => Exec["reload-apache2"];
	}


   # Let's make sure we've got apache2 installed
   kpackage {
	"apache2":
		ensure => installed;
	"libapr1":
		ensure => latest;
   }

   # We want to make sure that Apache2 is running.
   service { "apache2":
      ensure => running,
      hasrestart => true,
      require => Package["apache2"],
   }

   # Notify this when apache needs a reload. This is only needed when
   # sites are added or removed, since a full restart then would be
   # a waste of time. When the module-config changes, a force-reload is
   # needed.
   exec { "reload-apache2":
        command => "/etc/init.d/apache2 reload",
        refreshonly => true,
   }

	exec { "force-reload-apache2":
		command     => "/etc/init.d/apache2 force-reload",
		refreshonly => true,
		require     => Exec["reload-apache2"];
	}

   file { "/etc/apache2/conf.d":
      recurse => true,
      notify => Exec["reload-apache2"],
      require => Package["apache2"],
   }

   if !$apache_ports {
      $apache_ports = 80
   }

   if !$apache_virtualhosts {
      $apache_virtualhosts = $ipaddress
   }

   if !$apache_virtualhosts_ssl {
      $apache_virtualhosts_ssl = ""
   }

   file { "/etc/apache2/httpd.conf":
      content => template("apache/httpd.conf"),
      owner => root,
      group => root,
      mode => 644,
      backup => false,
      require => Package["apache2"],
   }

   kfile { "/etc/apache2/ports.conf":
      owner   => root,
      group   => root,
      mode    => 644,
      require => Package["apache2"],
      notify  => Exec["reload-apache2"],
   }

   define apache_ports {
   	line { "open apache port ${name}":
		content => "Listen $name",
		file    => "/etc/apache2/ports.conf",
		notify  => Exec["reload-apache2"],
		require => Package["apache2"],
	}
   }

   apache_ports { $apache_ports:; }

   # A directory where we can put extra configuration statements for sites.
   # Every site has its own subdirectory where files can be put. The default
   # vhost template includes all files in this site directory. This allows us
   # to add minor additions to a vhost configuration without having to define a
   # completely new template or config file.
   file { "/etc/apache2/vhost-additions":
        ensure => directory,
        mode => 755,
        owner => root,
        group => root,
        require => Package["apache2"],
   }

   # Use a site template for adding the websites, this is for easy adding
   # of new files, with or without Tomcat.
   define site_config ($address = "*:80", $serveralias = false,
                       $scriptalias = false, $documentroot = "/var/www",
                       $tomcatinstance = "", $proxy_port = "",
                       $djangoproject = "", $djangoprojectpath = "",
                       $ssl_ipaddress = "*", $ssl_ip6address = "", $template = "apache/sites-available/simple.erb") {
        $domain = $name
        file { "/etc/apache2/sites-available/$name":
                ensure => file,
                owner => root,
                group => root,
                mode => 644,
                backup => false,
                content => template($template),
                require => Package["apache2"],
                notify => Exec["reload-apache2"],
        }

        file { "/etc/apache2/vhost-additions/$name":
                ensure => directory,
                owner => root,
                group => root,
                mode => 755,
                require => File["/etc/apache2/vhost-additions"],
        }
   }
}

class apache::headers {
	apache::module { "headers":; }
}
