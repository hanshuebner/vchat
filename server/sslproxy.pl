#!/usr/bin/perl -w

use strict;
use IO::Socket::SSL;
use IO::Socket;
use IO::Select;
use conf;

foreach ([ $SSLkeyFile,  "SSL private key file" ],
	 [ $SSLcertFile, "SSL server certificate file", ],
	 [ $SSLcaFile,   "SSL CA file", ],
	 [ $CAindex,	 "CA index file", ]) {
    my ($file, $description) = @$_;
    if (not -f $file or not -r $file) {
	warn "$0: can't access $description $file ($!)\n";
	exit (1);
    }
}

$^W = 0;
my $serverSocket = IO::Socket::SSL->new( Proto            => 'tcp',
					 LocalPort        => $SSLport,
					 Listen           => &SOMAXCONN,
					 Reuse            => 1,
					 SSL_verify_mode  => 1,
					 SSL_verify_depth => 1,
					 SSL_key_file     => $SSLkeyFile,
					 SSL_cert_file    => $SSLcertFile,
					 SSL_ca_file      => $SSLcaFile);
$^W = 1;

$serverSocket or die "$0: can't setup SSL client listen socket ($!)\n";

print STDERR "$0: accepting SSL chat clients on port $SSLport\n";

$SIG{CLD} = 'IGNORE';

while (1) {

    my $client;

    while ($client = IO::Socket::accept($serverSocket, 'IO::Socket::INET')) {

	print STDERR "$0: new connection, forking\n";

	my $childPid = fork;

	if ($childPid == 0) {
	    $serverSocket->close();
	    handleClient($client, $serverSocket);
	    exit;
	} else {
	    $client->close();
	}
    }
}


sub handleClient {
    my $clientSocket = shift;
    my $serverSocket = shift;
    my $args = ${*$serverSocket}{'_arguments'};
    my $class = "IO::Socket::SSL";

# This routine is effectively ripped out of IO::Socket::SSL.  We use IO::Socket::accept instead
# of IO::Socket::SSL::accept and perform the SSL handshake in the child process to prevent
# malicious or errorneous clients from blocking the whole SSL proxy process.
    
####### BEGIN RIPPED CODE #######

    my $clientFileno = fileno($clientSocket);

    # create the SSL object.
    my $ssl_obj;
    if (!($ssl_obj = SSL_SSL->new($clientSocket, $args)) ) {
	return undef;
    }
    ${*$clientSocket}{'_SSL_SSL_obj'} = $ssl_obj;

    my $ssl = $ssl_obj->get_ssl_handle();
    my $r;
    if (($r = Net::SSLeay::accept($ssl)) <= 0 ) { # ssl/s23_srvr.c
	my $err_str = $serverSocket->_get_SSL_err_str();
        print STDERR "$0: [$$] SSL handshake for client failed: $err_str\n";
	return $serverSocket->_myerror("SSL_accept: '$err_str'.");
    }

    # make $clientSocket a IO::Socket::SSL object and tie it.
    bless $clientSocket, $class;

    my $clientHandle = tie *{$clientSocket}, $class, $clientSocket;
    if (!$clientHandle) {
	print STDERR "$0: [$$] cannot tie: '$!'.\n";
	next;
    }

####### END RIPPED CODE #######

{ # this block is here to work around emacs screwing up indentation

    print STDERR "$0: [$$] connection opened. clientSocket: $clientSocket, fileno: $clientFileno.\n";

    open(ENV, ">$pidsDir/$$")
	or warn "$0: [$$] can't create auth info file $pidsDir/$$: $!\n";

    print ENV "FROM=", $clientHandle->peerhost, "\n";

    my ($peer_cert, $subject_name, $issuer_name, $date, $str);
    
    if (($peer_cert = $clientHandle->get_peer_certificate())) {
        my $subject_name = $peer_cert->subject_name;
	my $issuer_name = $peer_cert->issuer_name;

        print STDERR "$0: [$$] subject: '$subject_name'\n";
        print STDERR "$0: [$$] issuer: '$issuer_name'.\n";

	if ($subject_name =~ m-/CN=([^/]*)/-) {
	 my $nick = $1;

         open(CA_INDEX,$CAindex);

# Checks if the certificate is revoked, if so.. drop user!
# this is a dirty hack, because I only check the CA index file and don't do 
# proper certificate validation

         while(<CA_INDEX>) {
	  if(/^R/ and m-$subject_name-) {
           $clientHandle->close();
           close(CA_INDEX);
           close(ENV);
           return;
	  } 
	 }

	 close(CA_INDEX);

	 print ENV "CHATNICK=$nick\n";

	}

    } else { # wir wollen nicht dass untrustet user joinen
      $clientHandle->close();
      close(ENV);
      return;

   }
    close(ENV);

    my $serverHandle = IO::Socket::INET->new( Proto    => "tcp",
					      PeerAddr => "localhost",
					      PeerPort => $clientPort)
        or die "$0: [$$] cannot connect to chat server on localhost:$clientPort\n";

    print STDERR "$0: [$$] connected to chat server\n";
    
    my $select = IO::Select->new($serverHandle, $clientFileno);

  chat:
    while (1) {
	my $buf;

	my @readable = $select->can_read;

	foreach (@readable) {
	    if ($_ eq $serverHandle) {
		if (!$serverHandle->sysread($buf, 1024)) {
		    print STDERR "$0: [$$] read from chat server failed\n";
		    last chat;
		}
		if (!$clientHandle->write($buf, length $buf)) {
		    print STDERR "$0: [$$] write to client failed\n";
		    last chat;
		}
	    } else {
		if (!$clientSocket->sysread($buf, 1024)) {
		    print STDERR "$0: [$$] read from client failed\n";
		    last chat;
		}
		if (!$serverHandle->write($buf, length $buf)) {
		    print STDERR "$0: [$$] write to chat server failed\n";
		    last chat;
		}
	    }
	}
    }
    $serverHandle->close();
    $clientHandle->close();

    print STDERR "$0: [$$] connection terminated\n";
}
}

