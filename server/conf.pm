#!/usr/bin/perl5

package conf;
use Exporter;
use vars qw( @ISA @EXPORT );
@ISA = qw(Exporter);
@EXPORT = qw(
	     $libDir
	     $etcDir
	     $logDir
	     $logFile
	     $urlMapFile
	     $urlIDFile
	     $pidsDir
	     $nicksDir
	     $completionDir
	     $authorizedKeysFile
	     $authorizedKeysFileTwo
	     $caIndexFile
	     $debug
	     $maxMessageLength
	     $maxNickLength
	     $maxHostLen
	     $maxTopicLen
	     $clientPort
	     $clientSSLport
	     $SSLport
	     $SSLkeyFile
	     $SSLcertFile
	     $SSLcaFile
	     $maxClients
	     $psCommand
	     $CAindex
	     );

$libDir = "/usr/local/lib/vchat";
$etcDir = "/usr/home/vchatd/vchat/etc";
$spoolDir = "/var/spool/vchat";
$pidsDir = "$spoolDir/pids";
$nicksDir = "$spoolDir/nicks";
$completionDir = "$spoolDir/nicks";
$urlMapFile = "$spoolDir/urlmap.txt";
$urlIDFile = "$spoolDir/mapid.txt";
$logDir = "/var/log";
$authorizedKeysFile = "/usr/home/vchat/.ssh/authorized_keys";
$authorizedKeysFileTwo = "/usr/home/vchat/.ssh/authorized_keys2";
$caIndexFile = "/usr/home/vchatca/vchat/CA.index";

$logFile = $logDir . "/chatserver.log";

$debug = 0;
$maxMessageLength = 1024;	# max. length of messages accepted by
				# clients.  Excess bytes are cut off
				# by the server.
$maxNickLength = 20;		# max. length of a nickname
$maxHostLen = 40;		# maximum length of a host name
$maxTopicLen = 80;		# maximum length of a channel topic

$clientPort = 2323;		# clients connect to this port

$maxClients = 150;		# hard client count limit

# SSL proxy Configuration

$SSLport = 2325;		# SSL clients connect to this port
my $certHome = "/usr/home/vchatca/vchat/certs";
$SSLkeyFile = "$certHome/vchat.key";
$SSLcertFile = "$certHome/vchat.cert";
$SSLcaFile = "$certHome/vchat-ca.cert";
$psCommand = "ps -ax -opid=,command=";  # freebsd
#$psCommand = "env UNIX95=1 ps -e -opid= -oargs=";     # hp-ux

$CAindex = "/usr/home/vchatca/vchat/CA.index";

1;
