#!/usr/bin/perl -w -I/usr/home/vchatd/vchat/server

use POSIX qw/strftime/;
use conf;
use strict;
use HTTP::Daemon;

my $httppath = "/rd";
my $entriesperpage = 25;
my $pagesdelta = 5;
my $localaddress = "127.0.0.1";
my $localport = 8080;

my $head = '    <head>
        <title>vchat - url archiv</title>
        <style type="text/css">
			p,td,li,ul {font-family:verdana,arial,helvetica; font-size:12pt;}
			a:link {color:#000066;}
			a:visited {color:#000066;}
			a:hover {color:#CC0000; text-decoration:underline}
			a {text-decoration:none;}
			#s {font-size:8pt;}
			.red { color: red; }
        </style>
    </head>
';

unless (open(URLMAP, $urlMapFile)) {
    die "$0: can't open $urlMapFile: $!\n";
}

my %urlMap;
my @urls;
my $count = 0;

sub load_new_urls {
    while (<URLMAP>) {
        chomp;
	my ($time, $key, $nick, $url, $description) = split(/\s+/, $_, 5);
	my($timeparsed) = strftime("%d.%m.%Y %H:%M", localtime $time);
	$urlMap{$key} = $url;
	$url =~ s/[\'\"]//g;
	$description =~ s/\&/&amp;/g;
	$description =~ s/</&lt;/g;
	$description =~ s/>/&gt;/g;
	my $skey = substr($key, 0, 42);
	my $link = "<a href=\"$url\">$skey</a>";
        my $urlfile;
#        if(-e "/usr/home/vchatd/url-crawler/url-files/$key") {
	    $urlfile = "<a href=\"https://vchat\.berlin\.ccc\.de/url-crawler/$key\">[archive]</a>";
#        } else {
#	    $urlfile = "";
#        };
	my $nicklink = "<a href=\"$httppath?$nick\"><b>$nick</b></a>";
	$count++;
	push @urls, [ $timeparsed, $link, $urlfile, $nicklink, $description,$url,$time,$nick,$key];
    }
    #print "urls umdrehen\n";
    #@urls = reverse(@urls);
    seek(URLMAP, 0, 1);		# reset eof condition
}

sub serve_request
{
	@urls = reverse(@urls);
    my ($page, $query) = @_;

#    print STDERR "got ", scalar @urls, " urls to work on\n";

#    print STDERR "p: $page q: $query\n";

    if ($page eq "") {
	$page = 0;
    }

    # unescape
    $query =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    # nur alphanumerische Zeichen, ".","-" oder "_" erlaubt
    $query =~ s/[^\w\.\_\-]//g;
    # escape "."
    $query =~ s/\./\\./g;


    # Suchanfrage
    if (length($query)!=0) {
	print "HTTP/1.1 200 OK\r\n";
	print "Server: vchat-rd/1.0\r\n";
	print "Cache-control: no-cache\r\nContent-Type: text/html; charset=\"UTF-8\"\r\n\r\n";
        print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2//EN\">";
        print "<html>\n";
	print $head;

	print "Suche nach \"$query\":<br>";
	print "<table border=\"0\">";
	foreach my $entry (@urls) {
	    if (($$entry[1] =~ /$query/i)||($$entry[3] =~ /$query/i)||($$entry[4] =~ /$query/i)) {
		my @entry = @$entry;
		pop @entry;
		pop @entry;
		print "<tr><td>", join("</td><td>", @entry), "</td></tr>\r\n";
	    }
	}
	print "</table>\r\n";
        print "</html>";
	exit 0;

	# Teilanfrage
    } elsif ($page =~ /^\d+$/) {
        $page = int($page);

	print "HTTP/1.1 200 OK\r\n";
	print "Server: vchat-rd/1.0\r\n";
	print "Cache-control: no-cache\r\nContent-Type: text/html;charset=\"UTF-8\"\r\n\r\n";



    print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">";
    print "<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"de\">\n";
    print $head;

    print "    <body>\n";
	print "        <p>Seite ".($page+1).":</p>\n";

	#skipping $entriesperpage * $page
	my $base = $entriesperpage * $page;

	print "        <table border=\"0\" cellpadding=\"2\">\n";
	# only the next $entriesperpage
	for(my $i = $base; $i < $base + $entriesperpage; $i++) {
	    if (my $entry = $urls[$i]) {
		my @entry = @$entry;
		pop @entry;
		pop @entry;
		print "<tr><td>", join("</td><td>", @entry), "</td></tr>\r\n";
	    }
	}


	# the footer
	if($count > $entriesperpage) {
	    my $start =  ($page>$pagesdelta) ? ($page-$pagesdelta) : 0;
	    my $countpages = int(($count-1)/$entriesperpage);
	    my $end = ($countpages>$page+$pagesdelta) ? ($page+$pagesdelta) : $countpages;
	    my $i;

	    print "<tr><td colspan=\"5\">";
	    if ($page != 0) {
			print "<a href=\"$httppath/".($page-1)."\">ryq</a>";
	    }

	    if($start!=0) {
			print " ... ";
	    }

	    for($i = $start; $i < $page; $i++) {
			print "<a href=\"$httppath/$i\">".($i+1)."</a> - ";
	    }

	    print "<span class=\"red\">".($i+1)."</span>";

	    for($i++; $i <= $end; $i++) {
			print " - <a href=\"$httppath/$i\">".($i+1)."</a> ";
	    }

	    if($countpages!=$end) {
		print " ... ";
	    }                

	    if ($page != $end) {
		print " <a href=\"$httppath/".($page+1)."\">vor</a>";
	    }
	    print "</td></tr>\r\n";
	}

	print "        </table>\r\n";
#	print "<p>[ <a href=\"https://gabe1.h3q.com/mrtg/vchat.berlin.ccc.de/\">vchat user-mrtg</a> ]</p>\n";
	print "    </body>\n";
    print "</html>\n";
	return;

	# latest
    } elsif ($page  eq "latest") {
		print "HTTP/1.1 301 Moved Permanently\r\n";
		print "Location: ".$urls[0][5]."\r\n\r\n";
		#print "Location: ".$urls[$#urls][5]."\r\n\r\n";
		#print "Content-type: text/html\n\n>".$urls[$#urls][5]."<";
		return;
	
	# rss auf Wunsch von neuro
    } elsif ($page  =~ /^rss\/{0,1}([0-9]*)([s|d|m|h]{0,1})/ ) {
		print "HTTP/1.1 200 OK\r\n";
		print "Server: vchat-rd/1.0\r\n";
		print "Content-Type: application/rss+xml\r\n\r\n";

        my ($deltat);
	    if($2 eq "d") {
		    $deltat = int($1)*3600*24;
        } elsif ($2 eq "m") {
		    $deltat = int($1)*60;
        } elsif ($2 eq "s") {
		    $deltat = int($1);
        } elsif ($2 eq "h") {
		    $deltat = int($1)*3600;
        } else {
		    $deltat = 0;
        }

        if($deltat==0){ $deltat=3600*24; }


        use Time::Local;
        my @t = localtime();
        my $lt = timelocal(@t);
        my $gt = timegm(@t);
        my $diff = abs($lt-$gt);
        $diff % 3600 && die "strange offset: $diff";
        my $timediff = ($lt<$gt?'+':'-').('0'.($diff/3600).':00');

        print   "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n".
                "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"\n".
                "    xmlns=\"http://purl.org/rss/1.0/\"\n".
                "    xmlns:sy=\"http://purl.org/rss/1.0/modules/syndication/\"\n".
                "    xmlns:content=\"http://purl.org/rss/1.0/modules/content/\"\n".
                "    xmlns:dc=\"http://purl.org/dc/elements/1.1/\"\n";

        print    "<channel rdf:about=\"https://vchat.berlin.ccc.de/rd/\">\n".
                "    <title>vchat urilog</title>\n".
                "    <link>https://vchat.berlin.ccc.de/rd/</link>\n".
                "    <description>Log file of dropped vchat URIs</description>\n".
                "    <dc:language>en</dc:language>\n".
                "    <dc:creator>the vchat team</dc:creator>\n".
                "    <dc:date>".sprintf("%04i-%02i-%02iT%02i:%02i%s",($t[5]+1900),$t[4]+1,$t[3],$t[2],$t[1],$timediff)."</dc:date>\n".
                "    <dc:language>de-de</dc:language>\n".
                "    <dc:rights>4 UrhG - Sammelwerke und Datenbanken</dc:rights>\n".
                "    <sy:updatePeriod>hourly</sy:updatePeriod>\n".
                "    <sy:updateFrequency>1</sy:updateFrequency>\n".
                "    <sy:updateBase>".sprintf("%04i-%02i-%02iT%02i:%02i%s",($t[5]+1900),$t[4]+1,$t[3],$t[2],0,$timediff)."</sy:updateBase>\n";

        print   "     <items>\n".
                "          <rdf:Seq>\n";

        foreach my $entry (@urls) {
            if((time()-$$entry[6])<($deltat)) {
                $$entry[0] =~ s/(\d+)\.(\d+)\.(\d+) (\d+:\d+)/$3-$2-$1T$4/;

                print "            <rdf:li rdf:resource=\"https://vchat.berlin.ccc.de/rd/".$$entry[8]."\" />\n";
            } else {
                last;
            }
        }

        print   "        </rdf:Seq>\n".
                "    </items>\n";

        print   "</channel>\n"; 

        foreach my $entry (@urls) {
            if((time()-$$entry[6])<($deltat)) {
                $$entry[0] =~ s/(\d+)\.(\d+)\.(\d+) (\d+:\d+)/$3-$2-$1T$4/;
                print "<item rdf:about=\"https://vchat.berlin.ccc.de/rd/".$$entry[8]."\">\n";
                print "    <title>".$$entry[4]."</title>\n";
                print "    <link>".$$entry[5]."</link>\n";
                print "    <dc:creator>".$$entry[7]."</dc:creator>\n";
                print "    <dc:date>".$$entry[0]."$timediff</dc:date>\n";
                print "</item>\n";
            } else {
                last;
            }
        }
        print "</rdf:RDF>\n";
    return;

    } else {
		if (defined $urlMap{$page}) {
            print "HTTP/1.1 301 Moved Permanently\r\n";
            print "Location: $urlMap{$page}\r\n\r\n";
            return;
        }
    }
}

my $d = HTTP::Daemon->new(LocalAddr => $localaddress,
			  LocalPort => $localport,
			  Reuse => 1) || die;

load_new_urls();


print "Please contact me at: <URL:", $d->url, ">\n";
while (my $c = $d->accept) {
    load_new_urls();
    unless (fork) {
	select($c);
	my $r = $c->get_request;
	if ($r->url->path =~ m-/rd/?(.*)-) {
	    my $page = $1;
	    my $query = $r->{_uri};
	    if ($query =~ /\?/) {
		$query =~ s/.*\?//;
	    } else {
		$query = "";
	    }
	    serve_request($page, $query);
	} else {
	    print "HTTP/1.1 200 OK\r\n";
	    print "Server: vchat-rd/1.0\r\n";
	    print "Content-Type: text/plain\r\n\r\nnot found\r\n";
	}
	$c->close;
	undef($c);
	exit;
    }
    $c->close;
    while (wait != -1) {
    }
}
