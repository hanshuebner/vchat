#!/usr/bin/perl

# eingefuegt by chef
$SIG{INT} = 'IGNORE';

chdir("/var/spool/vchat/nicks");

$bin = "/home/vchatd/vchat/client";

$ENV{LC_CTYPE} = 'de_DE.ISO_8859-1';

$from = `who am i`;
chomp $from;
$from =~ s/.*\((.*)\).*/$1/;
if ($from =~ /^(\d+\.\d+\.\d+\.\d+)$/) {
    my $name = `host $1`;
    if ($name =~ /Name: (\S+)/) {
	$from = $1;
    }
}
if (not defined $ENV{'FROM'}) {
	$ENV{'FROM'} = $from . ":" . $ENV{'TERM'};
} else {
	$ENV{'FROM'} = $ENV{'FROM'} . ":" . $from . ":" . $ENV{'TERM'};
}

my $ppid = getppid();

`env > /var/spool/vchat/pids/$ppid`;
`env > /var/spool/vchat/pids/$$`;

if ($ENV{TERM} eq 'su') {
	print STDERR "*** Connect to the chat server through the SSH tunnel now!\n";
	sleep(400);
	exit(0);
}

`stty intr ^c kill ^u erase ^h discard ^o`;

$ENV{'CHATHELPERL'} = "/home/vchatd/vchat/client/vchat.pl";

if ($#ARGV > 0) {
	my ($option, $nick) = @ARGV;
	if ($option eq "-c") {
		$ENV{'CHATNICK'} = $nick;
	}
}

exec("$bin/vchat");
