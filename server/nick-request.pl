#!/usr/bin/perl -w

use strict;
use IO::Socket;

my $tmpBase = "/tmp/vchat-keygen-$$";
my $keyBase = "$ENV{HOME}/.vchat";

my $keyFile = "$keyBase.key";
my $certFile = "$keyBase.cert";
my $requestFile = "$keyBase.csr";

my $keyConfFile = "$tmpBase.keyconf";

my $caHost = 'vchat.vaxbusters.org';
my $caPort = 2326;

# check if openssl is in PATH
my $tool = "openssl";

my $toolFound = map { my $p = "$_/$tool"; if (-f $p) { 1 } else { () }  } split(/:/, $ENV{PATH});

if (not $toolFound) {
    die "$0: cannot find program '$tool' in PATH environment, can't continue\n";
}

my ($nick, $email);

if (-f $certFile) {
    print "You already have a RSA key ($keyFile) and certificate ($certFile)\n";
    exit;
}

print "vchat nick registration procedure

Note:  This procedure connects to the chat server to register your nickname
through the Internet.  Data will be transmitted.  If you are paranoid, don't
register.

Have you read this and do you really want to continue? (y/n) ";

my $reply = scalar <STDIN>;

if ($reply !~ /^y/) {
    print "I see, you want to play safe.  No data has been changed.  Bye.\n";
    exit;
}

END {
    system("rm -f $tmpBase.* 2>&1 >/dev/null");
}

if (-f $requestFile) {
    print "\
Certificate request file $requestFile found.
Delete old parameters? (y/n)";
    $reply = scalar <STDIN>;

    if ($reply =~ /^y/i) {
	unlink($requestFile)
	    or die "$0: can't delete request file $requestFile: $!\n";
	print "Old request file deleted.\n";
    } else {
	print "Retrying registration with the old paramters\n";
    }
}

if (not -f $requestFile) {

    while (1) {
	print "Enter your desired nick name: ";
	$nick = scalar <STDIN>; chomp $nick;
	print "Enter your email address: ";
	$email = scalar <STDIN>; chomp $email;

	print "Nick name: $nick\nEmail address: $email\nOK? (y/n) ";
	my $reply = scalar <STDIN>;
	if ($reply =~ /^y/i) {
	    last;
	}
    }

    open(KEYCONF, ">$keyConfFile")
	or die "$0: can't create $keyConfFile: $!\n";
    print KEYCONF "
[ req ]
default_bits                    = 2048
default_keyfile                 = user.key
distinguished_name              = req_distinguished_name
string_mask                     = nombstr
req_extensions                  = v3_req
[ req_distinguished_name ]
commonName                      = Name
commonName_max                  = 64
commonName_value		= $nick
emailAddress                    = Email Address
emailAddress_max                = 40
emailAddress_value		= $email
[ v3_req ]
nsCertType                      = client
basicConstraints                = critical,CA:false
";
    close(KEYCONF);

    if ( -f $keyFile ) {
        print "RSA key generation skipped.\nRSA key file $keyFile exists, not overwritten\n";
    } else {
        print "Generate RSA key pair

You will be asked for your passphrase after generation.  The passphrase
protects your key locally
";
        system("openssl genrsa -des3 -out $keyFile 2048");

        if (! -s $keyFile) {
            unlink($keyFile);
            print "Key generation failed, try again\n";
            exit;
        }
    }

    print "Generate certificate request\n";

    system("openssl req -new -config $keyConfFile -key $keyFile -out $requestFile");
}

print "

Now connecting to the chatserver ($caHost) and sending the certificate
request.

You need to have a working Internet connect to register your nick
name.  Also, the chat operator will possibly need to be present to
authorize your nick registration request.  If no chat operator is
currently online, your request will hang and you will have to restart
this procedure at a later time.

Note: This program will transmit only your certificate request to the
chat server.  No other information is transmitted.  The chat server
will return your certificate which you can use to chat under your
registered nick name.

The certificate will be stored in the file $certFile

You may copy it to other machines from which you wish to use your
registered nick name.\n";

print "Press [return] when you are ready to connect and register,\nor type q to quit: ";
my $reply = scalar <STDIN>;

if ($reply ne "\n") {
    print "Okay.  No network connection has been established.
Restart this program to restart registration.\n";
    exit;
}

my $request = `cat $requestFile`;

my $socket = IO::Socket::INET->new(Proto     => "tcp",
                                   PeerAddr  => $caHost,
                                   PeerPort  => $caPort)
    or die "$0: Can't connect to port $caPort on $caHost: $!\n";

print "Connected, sending certificate request\n";

$socket->write($request, length $request)
    or die "$0: can't send certificate request to remote: $!\n";

print "Waiting for reply from certificate authority (may take two minutes)\n";

my $cert = "";
while ($socket->sysread($cert, 8192, length $cert) > 0) {
    if ($cert =~ /END CERTIFICATE/sm) {
	last;
    }
}

if ($cert !~ /END CERTIFICATE/sm) {
    print "Sorry, could not receive certificate from remote.\nReason: $cert\n";
    exit;
}
open(CERT, ">$certFile")
  or die "$0: can't create certificate file $certFile: $!\n";
print CERT $cert;
close(CERT);

print "Certificate saved in $certFile.  Have fun.\n";

unlink($requestFile);
