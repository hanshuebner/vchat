#!/opt/local/bin/perl -w -I/home/hans/vchat/server

use POSIX qw/strftime/;
use conf;
use strict;

my $httppath = "/rd";
my $entriesperpage = 25;

if (open(URLMAP, $urlMapFile)) {
    my %urlMap;
    my @urls;
    my $count =0;
    while (<URLMAP>) {
	my ($time, $key, $nick, $url, $description) = split(/\s+/, $_, 5);
	$time = strftime("%d.%m.%Y %H:%M", localtime $time);
	$urlMap{$key} = $url;
	$url =~ s/['"]//g;
	$description =~ s/\&/&amp;/g;
	$description =~ s/</&lt;/g;
	$description =~ s/>/&gt;/g;
	my $link = "<a href=\"$url\">$key</a>";
	my $nicklink = "<a href=\"$httppath?$nick\">$nick</a>";
	$nick = "<b>$nick</b>";
	$count++;
	push @urls, [ $time, $link, $nicklink, $description ];
    }
    close(URLMAP);

    my $path = $ENV{PATH_INFO};
    $path =~ s-^/--;
    my $query = $ENV{QUERY_STRING};
    # unescape
    $query =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    # nur alphanumerische Zeichen, "." oder "_" erlaubt
    $query =~ s/[^\w\.\_]//g;
    # escape "."
    $query =~ s/\./\\./g;

    # Suchanfrage
    if (length($query)!=0) {
	print "Cache-control: no-cache\r\nContent-Type: text/html\r\n\r\n";
	print "Suche nach \"$query\":<BR>";
	print "<table>";
	while (my $entry = pop @urls) {
		if (($$entry[2] =~ /$query/i)||($$entry[3] =~ /$query/i)) {
			print "<tr><td>", join("</td><td>", @$entry), "</td></tr>\r\n";
		}
	}
	print "</table>\r\n";
	exit 0;

    # Teilanfrage
    } elsif ($path =~ /^[0-9]+$/) {
	print "Cache-control: no-cache\r\nContent-Type: text/html\r\n\r\n";
	print "Seite ".($path+1).":<BR>";

	#skipping $entriesperpage * $path
	my $i;
	for($i=0;($i<($entriesperpage*$path)) &&  (pop @urls);$i++){};

	print "<table>";
	# only the next $entriesperpage
	for($i=0;$i<$entriesperpage;$i++) {
		if (my $entry = pop @urls) {
			print "<tr><td>", join("</td><td>", @$entry), "</td></tr>\r\n";
		}
	}


	# the footer
	if($count > $entriesperpage) {
		print "<tr><td colspan=4>";
		if ($path != 0) {
			print "<a href=\"$httppath/".($path-1)."\">ryq</a> - ";
		}
		for($i=0;$i<$path;$i++) {
			print "<a href=\"$httppath/$i\">".($i+1)."</a> - ";
		}
		print "<font color=red>".($i+1)."</font>";
		for($i++;$i<=(int(($count-1)/$entriesperpage));$i++) {
			print " - <a href=\"$httppath/$i\">".($i+1)."</a> ";
		}
		if ($path != (int(($count-1)/$entriesperpage))) {
			 print " - <a href=\"$httppath/".($path+1)."\">vor</a>";
		}
		print "</td></tr>\r\n";
	}

	print "</table>\r\n";
	exit 0;

    } elsif ($path eq "") {
	print "Cache-control: no-cache\r\nContent-Type: text/html\r\n\r\n<table>";
	while (my $entry = pop @urls) {
	    print "<tr><td>", join("</td><td>", @$entry), "</td></tr>\r\n";
	}
	print "</table>\r\n";
	exit 0;

    } elsif ($path eq "last") {
      print "Cache-control: no-cache\r\nContent-Type: text/html\r\n";
      print"Content-type: text/html\n\ntest";
      exit(0);

    } else {

	if (defined $urlMap{$path}) {
	    print "Location: $urlMap{$path}\r\n\r\n";
	    exit 0;
	}
    }
}

print <<bla
Status: 404 Not Found
Server: Apache/1.3.20 (Unix)
Connection: close
Content-Type: text/html; charset=iso-8859-1

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML><HEAD>
<TITLE>404 Not Found</TITLE>
</HEAD><BODY>
<H1>Not Found</H1>
The requested URL was not found on this server.<P>
<HR>
</BODY></HTML>
bla
;
