# Author: Kumina bv <support@kumina.nl>

# Class: gen_haproxy
#
# Parameters:
#  haproxy_loglevel
#    Loglevel
#  forwardfor
#    Add HTTP X-Forwarded-For header to backend request
#  tcp_smart_connect
#    Set to false to disable tcp smart connect. This could prevent some TCP problems.
#
# Actions:
#  Installs HAProxy
#
# Depends:
#  gen_puppet
#
class gen_haproxy ($haproxy_loglevel="warning") {
  kservice { "haproxy":
    ensure => 'running';
  }

  # Yes, we would like to be able to start the service...
  file { "/etc/default/haproxy":
    content => "ENABLED=1\n",
    require => Package["haproxy"];
  }

  exec { "test-haproxy-config-and-reload":
    command     => "/usr/sbin/haproxy -c -f /etc/haproxy/haproxy.cfg > /dev/null 2>&1",
    refreshonly => true,
    notify      => Exec["reload-haproxy"];
  }

  concat { "/etc/haproxy/haproxy.cfg" :
    require => Package["haproxy"],
    notify  => Exec["test-haproxy-config-and-reload"];
  }

  # Some default configuration. Alter the templates and add the options when needed.
  concat::add_content { 'globals':
    target  => '/etc/haproxy/haproxy.cfg',
    content => template('gen_haproxy/global');
  }
}

# Define: gen_haproxy::site
#
# Actions:
#  This define exports the configuration for the load balancers. Use this to have webservers loadbalanced
#
# Parameters:
#  listenaddress
#    The external IP to listen to
#  port
#    The external port to listen on
#  balance
#    The balancing-method to use
#  timeout_connect
#    TCP connection timeout between proxy and server
#  timeout_server_client
#    TCP connection timeout between client and proxy and Maximum time for the server to respond to the proxy
#  timeout_http_request
#    Maximum time for HTTP request between client and proxy
#  timeout_check
#    Maximum time before a check is considered failed
#  source
#    The source IP for connections tpo backends
#
# Depends:
#  gen_puppet
#
define gen_haproxy::site($site, $mode="http", $balance="static-rr", $timeout_connect="5s", $timeout_server_client="5s", $timeout_http_request="5s", $httpcheck_uri=false, $cookie=false,
      $forwardfor_except=false, $httpclose=false, $timeout_server='20s', $redirect_non_ssl=false, $timeout_check='10s', $remove_external_forwarded_for=true, $source=false, $has_stunnel=false) {
  if !($balance in ["roundrobin","static-rr","source","leastconn"]) {
    fail("${balance} is not a valid balancing type (roundrobin, static-rr, leastconn or source).")
  }
  if !($mode in ["http","tcp"]) {
    fail("Please select either http or tcp as mode.")
  }
  $ip        = regsubst($name, '(.*)_.*', '\1')
  $temp_port = regsubst($name, '.*_(.*)', '\1')
  $port      = $temp_port ? {
    $name   => 80,
    default => $temp_port,
  }

  concat::add_content { "site_${name}_1_ip":
    target  => "/etc/haproxy/haproxy.cfg",
    content => template("gen_haproxy/ip");
  }
}

# Define: gen_haproxy::add_server
#
# Actions:
#  This define exports the configuration for the load balancers. Use this to have webservers loadbalanced
#
# Parameters:
#  cookie
#    The cookie option from HAProxy(see http://haproxy.1wt.eu/download/1.4/doc/configuration.txt)
#  httpcheck_uri
#    The URI to check if the backendserver is running
#  httpcheck_port
#    The port to check on whether the backendserver is running
#  httpcheck_interval
#    The interval in ms of the check
#  httpcheck_fall
#    The number of times a check should fail before the resource is considered down
#  httpcheck_rise
#    The number of times a check should succeed after downtime before the resource is considered up
#  backupserver
#    Whether this server is a backupserver or a normal one
#  servername
#    The hostname(or made up name) for the backend server
#  serverport
#    The port for haproxy to connect to on the backend server
#  serverip
#    The IP of the backend server
#  redir
#    Redirect to another site with a HTTP 302 status
#
# Depends:
#  gen_puppet
#
define gen_haproxy::site::add_server($cookie=false, $httpcheck_uri=false, $httpcheck_port=false, $httpcheck_interval=false, $httpcheck_fall=false, $httpcheck_rise=false, $backupserver=false,
    $serverip=$ipaddress_eth0, $serverport=80, $redir=false) {
  $real_name      = regsubst($name, '(.*);.*', '\1')
  $server_name    = regsubst($name, '.*;(.*)', '\1')
  $cookie_content = regsubst($server_name, '([^\.]*)\..*', '\1')

  concat::add_content { "site_${real_name}_2_server_${server_name}":
    target  => "/etc/haproxy/haproxy.cfg",
    content => template("gen_haproxy/server");
  }
}
