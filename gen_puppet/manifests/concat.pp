# A system to construct files using fragments from other files or templates.
#
# This requires at least puppet 0.25 to work correctly as we use some 
# enhancements in recursive directory management and regular expressions
# to do the work here.
#
# USAGE:
# The basic use case is as below:
#
# concat{"/etc/named.conf": 
#    notify => Service["named"]
# }
#
# concat::fragment{"foo.com_config":
#    target  => "/etc/named.conf",
#    order   => 10,
#    content => template("named_conf_zone.erb")
# }
#
# This will use the template named_conf_zone.erb to build a single 
# bit of config up and put it into the fragments dir.  The file
# will have an number prefix of 10, you can use the order option
# to control that and thus control the order the final file gets built in.
#
# SETUP:
# The class concat::setup defines a variable $concatdir - you should set this
# to a directory where you want all the temporary files and fragments to be
# stored.  Avoid placing this somewhere like /tmp since you should never
# delete files here, puppet will manage them.
#
# If you are on version 0.24.8 or newer you can set $puppetversion to 24 in 
# concat::setup to enable a compatible mode, else just leave it on 25
#
# If your sort utility is not in /bin/sort please set $sort in concat::setup
# 
# Before you can use any of the concat features you should include the 
# class concat::setup somewhere on your node first.
#
# DETAIL:
# We use a helper shell script called concatfragments.sh that gets placed
# in /usr/local/bin to do the concatenation.  While this might seem more 
# complex than some of the one-liner alternatives you might find on the net
# we do a lot of error checking and safety checks in the script to avoid 
# problems that might be caused by complex escaping errors etc.
# 
# LICENSE:
# Apache Version 2
#
# HISTORY:
# 2010/02/19 - First release based on earlier concat_snippets work
#
# CONTACT:
# R.I.Pienaar <rip@devco.net> 
# Volcane on freenode
# @ripienaar on twitter
# www.devco.net


# Sets up so that you can use fragments to build a final config file, 
#
# OPTIONS:
#  - mode       The mode of the final file
#  - owner      Who will own the file
#  - group      Who will own the file
#  - force      Enables creating empty files if no fragments are present
#  - warn       Adds a normal shell style comment top of the file indicating
#               that it is built by puppet
#
# ACTIONS:
#  - Creates fragment directories if it didn't exist already
#  - Executes the concatfragments.sh script to build the final file, this script will create
#    directory/fragments.concat and copy it to the final destination.   Execution happens only when:
#    * The directory changes 
#    * fragments.concat != final destination, this means rebuilds will happen whenever 
#      someone changes or deletes the final file.  Checking is done using /usr/bin/cmp.
#    * The Exec gets notified by something else - like the concat::fragment define
#  - Defines a File resource to ensure $mode is set correctly but also to provide another 
#    means of requiring
#
# ALIASES:
#  - The exec can notified using Exec["concat_/path/to/file"] or Exec["concat_/path/to/directory"]
#  - The final file can be referened as File["/path/to/file"] or File["concat_/path/to/file"]  
define concat($mode = 0644, $owner = "root", $group = "root", $warn = "false", $force = "false", $remove_fragments = "true" ) {
    $safe_name = regsubst($name, '/', '_', 'G')
    $concatdir = $gen_puppet::concat::setup::concatdir
    $version   = $gen_puppet::concat::setup::majorversion
    $sort      = $gen_puppet::concat::setup::sort
    $fragdir   = "${concatdir}/${safe_name}"

    $warnflag = $warn ? {
                    true      => "-w",
                    default     => "",
                }

    $forceflag = $force ? {
                    true      => "-f",
                    default     => "",
                }

    File{
        owner => $owner,
        group => $group,
        mode  => $mode,
    }

    file{$fragdir:
            ensure   => directory;

         "${fragdir}/fragments":
            ensure   => directory,
            recurse  => true,
            purge    => $remove_fragments,
            force    => true,
            ignore   => [".svn", ".git"],
            source   => $version ? {
                            24      => "puppet:///concat/null",
                            default => undef,
                        },
            notify   => Exec["concat_${name}"];

         "${fragdir}/fragments.concat":
            owner    => $owner,
            group    => $group,
            ensure   => present;

         $name:
            owner    => $owner,
            group    => $group,
            checksum => md5,
            mode     => $mode,
            ensure   => present,
            alias    => "concat_${name}";
    }

    exec{"concat_${name}":
        user      => $owner,
        group     => $group,
        notify    => File[$name],
        subscribe => File[$fragdir],
        alias     => "concat_${fragdir}",
        require   => [ File["/usr/local/bin/concatfragments.sh"], File[$fragdir], File["${fragdir}/fragments"], File["${fragdir}/fragments.concat"] ],
        unless    => "/usr/local/bin/concatfragments.sh -o ${name} -d ${fragdir} -t -s ${sort} ${warnflag} ${forceflag}",
        command   => "/usr/local/bin/concatfragments.sh -o ${name} -d ${fragdir} -s ${sort} ${warnflag} ${forceflag}",
    }
}

# Puts a file fragment into a directory previous setup using concat
# 
# OPTIONS:
#   - target    The file that these fragments belong to
#   - content   If present puts the content into the file
#   - source    If content was not specified, use the source
#   - order     By default all files gets a 10_ prefix in the directory
#               you can set it to anything else using this to influence the
#               order of the content in the file
#   - ensure    Present/Absent
#   - mode      Mode for the file
#   - owner     Owner of the file
#   - group     Owner of the file
define concat::fragment($target, $content='', $source='', $order=10, $ensure = "present", $mode = 0644, $owner = root, $group = root) {
    $safe_target_name = regsubst($target, '/', '_', 'G')
    $safe_name = regsubst($name, '/', '_', 'G')
    $concatdir = $gen_puppet::concat::setup::concatdir
    $fragdir = "${concatdir}/${safe_target_name}"

    # if content is passed, use that, else if source is passed use that
    # if neither passed, but $ensure is in symlink form, make a symlink
    case $content {
             "": {
                    case $source {
                             "": {
                                     case $ensure {
                                         "", "absent", "present", "file", "directory": {
                                                 crit("No content or source specified")
                                         }
                                     }
                                 }
                        default: { File{ source => $source } }
                    }
                 }
        default: { File{ content => $content } }
    }

    file{"${fragdir}/fragments/${order}_${safe_name}":
        mode   => $mode,
        owner  => $owner,
        group  => $group,
        ensure => $ensure,
        alias  => "concat_fragment_${safe_name}",
        notify => Exec["concat_${target}"]
    }
}

# Sets up the concat system, you should set $concatdir to a place
# you wish the fragments to live, this should not be somewhere like
# /tmp since ideally these files should not be deleted ever, puppet
# should always manage them
#
# $puppetversion should be either 24 or 25 to enable a 24 compatible
# mode, in 24 mode you might see phantom notifies this is a side effect
# of the method we use to clear the fragments directory.
# 
# The regular expression below will try to figure out your puppet version
# but this code will only work in 0.24.8 and newer.
#
# $sort keeps the path to the unix sort utility
#
# It also copies out the concatfragments.sh file to /usr/local/bin
class gen_puppet::concat::setup {
    $concatdir = "/var/lib/puppet/concat"
    $majorversion = regsubst($puppetversion, '^[0-9]+[.]([0-9]+)[.][0-9]+$', '\1')
    $sort = "/usr/bin/sort"

    file{"/usr/local/bin/concatfragments.sh": 
            owner  => root,
            group  => root,
            mode   => 755,
            source => $majorversion ? {
                        24      => "puppet:///concat/concatfragments.sh",
                        default => "puppet:///modules/gen_puppet/concat/concatfragments.sh"
                      };

         $concatdir: 
            ensure => directory,
            owner  => root,
            group  => root,
            mode   => 755;
    }
}
class gen_puppet::concat {
        include gen_puppet::concat::setup

        define add_content($target, $content, $order=15, $ensure=present) {
                $body = $content ? {
                        false   => $name,
                        default => $content,
                }

                concat::fragment{ "${target}_fragment_${name}":
                        content => "${body}\n",
                        target  => $target,
                        order   => $order,
			ensure  => $ensure;
                        }
                }
}

