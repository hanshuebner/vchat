#!/usr/bin/perl -w

use strict;
use IO::Socket;

my $caCommand = "openssl ca -config /home/hans/testCA/openssl.cnf";
my $requestDir = "/home/hans/testCA/certs";

my $caPort = 2326;
my $chatPort = 2323;

my $chatSocket = IO::Socket::INET->new( Proto     => "tcp",
					PeerAddr  => "localhost",
					PeerPort  => $chatPort)
    or die "$0: Can't connect to chat server on localhost:$caPort: $!\n";

my $server = IO::Socket::INET->new( Proto     => 'tcp',
				    LocalPort => $caPort,
				    Listen    => SOMAXCONN,
				    Reuse     => 1)
    or die "$0: can't setup listen socket on port $caPort: $!\n";

print $chatSocket ".l ca-clerk land-of-fortune(s) 14\n";

my $parentPid = $$;
if (!fork) {
    $server->close();
    while (1) {
	if ($chatSocket->eof) {
	    print STDERR "can't read from chat server, exiting\n";
	    last;
        }
	my $junk = scalar <$chatSocket>;
	print $junk;
	if ($junk =~ /^\*(.*?)\*/) {
	    my $nick = $1;
	    foreach (split(/\n/, `/usr/local/bin/fortune -S80`)) {
		s/\t/    /g;
		print $chatSocket ".m $nick $_\n";
	    }
	}
    }
    kill 15, $parentPid;
    exit;
}

print "[Server $0 accepting clients]\n";

$| = 1;

while (my $client = $server->accept()) {
    my $peerHost = $client->peerhost;
    print "connection from $peerHost\n";
    print $chatSocket ".m hans received a key registration connection from $peerHost\n";
    my $request = '';
    $client->autoflush(1);
    while ($client->sysread($request, 8192, length $request) > 0) {
	print "request: [$request]\n";
	if ($request =~ /-----END CERTIFICATE REQUEST-----/sm) {
	    last;
	}
    }

    if ($request !~ /-----END CERTIFICATE REQUEST-----/sm ) {
	print "Sorry, could not receive certificate from remote, please try again later\n";
	next;
    }

    my $certBase = "$requestDir/$peerHost.$$";
    my $requestFile = "$certBase.csr";
    my $certFile = "$certBase.cert";

    open(REQUEST, ">$requestFile")
	or die "$0: cannot create cert request file $requestFile: $!\n";
    print REQUEST $request;
    close(REQUEST);

    if (!fork) {
        alarm(60);
        exec("$caCommand -in $requestFile -out $certFile");
        die "$0: can't exec openssl: $!\n";
    }

    wait;

    if ($? == 0) {
        open(CERT, $certFile)
	    or die "$0: can't open cert file $certFile: $!\n";
        my $cert = join('', <CERT>);
        close(CERT);

        $client->syswrite($cert, length $cert);
    } else {
	my $message = "No operator present to sign request, try later";
	my $ready = '';
	print "Reason for rejection: ";
	vec($ready, fileno(STDIN), 1) = 1;
	if (select($ready, undef, undef, 30)) {
	    $message = scalar <STDIN>;
	    chomp $message;
	} else {
	    print "<timeout>\n";
	}
	$client->syswrite($message, length $message);
    }
    $client->close;
    print "Connection to client closed\n";
}
