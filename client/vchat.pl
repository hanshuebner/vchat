#!/usr/bin/perl -w --

# This perl file is read by vchat.cc and contains helper functions
# called by vchat during the chat conversation.

# sub serverMessage

# Reformat one or more chat server messages.  The message(s) are
# passed in as one string in protocol format (see protocol.doc).  The
# routine should return the reformatted messages(s).  Note that
# vchat.cc will perform simple interpretations on every returned line
# beginning with three digits.  All other lines are put to the user's
# screen verbatim.

my $lastInput = time;
my $beeped = 1;
my $idleBeep = 0;
my $myNick = undef;

sub serverMessage {
    my $message = shift;

    my $retval = "";

#    print "*perl* server message: [$message]\n";

    foreach (split(/\n/, $message)) {

	if (/^221 (\S+).*?\((.*)\)/) {
	    my $reason = "";
	    if ($2 ne "") {
		$reason = " ($2)";
	    }
	    $retval .= "* $1 left the chat$reason\r\n";

	} elsif (/^241 (\S+) (\S+)/) {
	    $retval .= "* $1 changed h** nick to $2\r\n";

	    if (defined $myNick
		and ($myNick eq $1)) {
		$myNick = $2;
	    }

	} elsif (/^118 (.*)/) {		# action
	    $retval .= "$1\r\n";

	} elsif (/^115 (\S+) *([^\r\n]*)/) {	# channel topic

	    my ($channel, $topic) = ($1, $2);

	    if ($topic eq "") {
		$retval .= "* No topic defined for channel $channel\r\n";
	    } else {
		$retval .= "* Topic for channel ${channel}: $topic\r\n";
	    }

	} elsif (/^116 (\S+) (\S+) (\S+) (\S+) (\S+) ([^\r\n]*)[\n\r]*$/) {
	    $retval .= "$_\n";
	    $retval .= 
		 "* Nickname........: $1\r\n"
	 	."* Initial Nickname: $2" . ($5 ? " (registered)" : "") . "\r\n"
		."* From............: $3\r\n"
		."* Address.........: $4\r\n";
	} else {
	    $retval .= $_ . "\n";
	}
    }

    if ($idleBeep > 0) {
	if ((time - $lastInput) >= $idleBeep) {
	    if ($retval =~ /$myNick/i) {
		print STDERR "\007";
		select(undef, undef, undef, 0.2);
		print STDERR "\007";
	    }
	}
    }

#    print "*perl* return: [$retval]\n";

    return $retval;
}

sub userInput {
    my $input = shift;

#    $input =~ s/<v*e*b*g>/<grin>/g;
    $input =~ s/: $//; # remove nick completion cruft
    $input =~ s/\s*: ?\)/ :)/; # trickery for smiles
    if ($input =~ /^%i\s*(\d)/) {
	$idleBeep = $1;
	$input = "";
    }

    if ($input =~ /^\.l (\S+)/) {
	$myNick = $1;
    }

    $lastInput = time;
    $beeped = 0;

    return $input;
}
