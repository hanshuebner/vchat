
package Client;
#use Net::Ident;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);

use strict;

use POSIX qw(strftime);
use Fcntl;
use Socket;

use conf;
use Completion;
use Unicode::MapUTF8 qw(to_utf8 from_utf8 utf8_supported_charset);

my %Extent;
my $clientCounter = 0;
my $startTime = time;

sub extent
{
    return values %Extent;
}

sub find {
    my $nick = shift;

    foreach (keys %Extent) {
	if (lc($_) eq lc($nick)) {
	    return $Extent{$_};
	}
    }

    return undef;
}

sub fileDescriptor {
    my $self = shift;

    return $self->{'fileDescriptor'};
}

sub all {
    return values %Extent;
}

sub count {
    my @clients = keys %Extent;
    return $#clients + 1;
}

sub deltaTimeString {
    my $idle = shift;
    if ($idle < 60) {
	return "${idle}s";
    }
    $idle = int($idle/60);
    if ($idle < 60) {
	return "${idle}m";
    }
    $idle = int($idle/60);
    if ($idle < 24) {
	return "${idle}h";
    }
    $idle = int($idle/24);
    return "${idle}d";
}

sub timeStamp {
    return strftime("%d.%m.%y %H:%M:%S", localtime time);
}

sub logMessage {
    my $line;
    foreach $line (split(/\n/, join("\n", @_))) {
	if ($line ne "") {
	    print STDERR timeStamp(), " $line\n";
	}
    }
}

sub isReservedNick {
    my $nick = shift;
    my $retval = 0;
    my @keylist;

    if (open(KEYS, $authorizedKeysFile) && open(KEYSTWO, $authorizedKeysFileTwo)) 
    {
	@keylist = <KEYS>;
	push (@keylist, <KEYSTWO>);
	foreach (@keylist) {
	    if (/"CHATNICK=$nick"/i) {
		$retval = 1;
	    }
	}
	close(KEYS);
	close(KEYSTWO);
    } else {
        warn "$0: can't open keys file $authorizedKeysFile or $authorizedKeysFileTwo: $!\n";
    }

  if ($retval == 0) {
      if (open(CA_INDEX, $caIndexFile)) {

	  foreach (<CA_INDEX>) {

	   if (m-/CN=$nick/-i) {
		  $retval = 1;
	   }

	  }

      } else {
	  warn "$0: can't open CA index file $caIndexFile: $!\n";
      }
  }

  return $retval;
}

sub getAuthorizationInfo
{
    my $self = shift;

    if (not defined $self->{'fileDescriptor'}) {
        return;
    }

    my $peerName = $self->{'fileDescriptor'}->peerhost();
    my $peerPort = $self->{'fileDescriptor'}->peerport();

    my %command;
    open(PS, "$psCommand|")
	or warn "$0: can't popen ps: $!\n";
    while (<PS>) {
	chomp;
	s/^\s*//;
	my ($pid, $command) = split(/\s+/, $_, 2);
	$command{$pid} = $command;
    }
    close(PS);


#    if (open(LSOF, "lsof -i \@$peerName:$peerPort -Fp|")) {
#	while (<LSOF>) {
#	    chomp;
#	    my $pid = $_;
#	    $pid =~ s/^p//;
#	    my $command = $command{$pid} || "<undef>";
#	print "[$pid] [$command]\n";
#	    if ($command =~ /(bin\/vchat|sslpr)/) { # match client processes only
#		$self->{'clientPid'} = $pid;
#	    }
#	}
#	close(LSOF);
#    } else {
#	warn "$0: can't open lsof: $!\n";
#    }

if (open(ST,"sockstat|grep $peerPort|")) {
  while(<ST>) {
    chomp;
    if( (/ *vchat *vchat *([0-9]*) */) 
         ||  
        (/ *vchatssl *perl *([0-9]*) */) 
      ) { 
        # problem: beide Prozesse haben selben Prozessnamen und Owner 
      print "found $_\n";
      my $pid = $1;
      my $command = $command{$pid} || "<undef>";
      print "[$pid] [$command]\n";
    #  if ($command =~ /(bin\/vchat|sslpr)/) { # match client processes only
        $self->{'clientPid'} = $pid;
    #  }
    }
  }
} else {
  warn "$0: can't open sockstat: $!\n";
}

print "Client.pm::clientPid: ".$self->{'clientPid'}."\n";
    my %clientEnv;
    if (defined($self->{'clientPid'})) {
	my $pid = $self->{'clientPid'};
	if (open(ENVDATA, "$pidsDir/$pid")) {
	    while (<ENVDATA>) {
		chomp;
		my ($key, $value) = split(/=/);
		$clientEnv{$key} = $value;
	    }
	    close(ENVDATA);
	    unlink("$pidsDir/$pid");
	} else {
	    warn "$0: can't open environment data file $pidsDir/$pid: $!\n";
	}
    }

    if (defined($clientEnv{CHATNICK})) {
	$self->{'authorizedNick'} = $clientEnv{CHATNICK};
    }
    if (defined($clientEnv{FROM})) {
	$self->{'authorizedFrom'} = $clientEnv{FROM};
    }
    # $self->send(Data::Dumper($self));
}

sub new {
    my $class = shift;
    my $fileDescriptor = shift;
    my $self = {};

    bless $self, $class;

    fcntl($fileDescriptor, &F_SETFL, &O_NONBLOCK) 
	or die "$0: can't set O_NONBLOCK flag for client socket: $!\n";

#    $self->{'ident'} = Net::Ident::lookup($fileDescriptor, 3);
    $self->{'ident'} = "";
    $self->{'from'} = "unknown";
    $self->{'fileDescriptor'} = $fileDescriptor;
    $self->{'fileDescriptor'}->autoflush(1);
    $self->{'nick'} = 'unknown' . $clientCounter++;
    $self->{'loggedIn'} = 0;
    $self->{'loginTime'} = time;
    $self->{'bytesIn'} = $self->{'bytesOut'} = 0;
    $self->{'ignore'} = [];
    $self->{'encoding'} = "ISO-8859-1";
    $self->resetIdleTime();

    $Extent{$self->{'nick'}} = $self;

    $self->{'authorizedNick'} = '';
    $self->{'authorizedFrom'} = 'localhost';

    $self->send("201 chat protocol version 1.0\r
100 Welcome to the chat.  Type '.h' for help");

    $self->showFile("$etcDir/motd");

    $self->getAuthorizationInfo();

    if ($self->{'authorizedNick'} ne '') {
	$self->send("120 $self->{'authorizedNick'} is your authorized nickname");
    } else {
	$self->send("121 You don't have an authorized nickname");
    }

    return $self;
}

sub channel
{
    my $self = shift;

    return $self->{'channel'};
}

sub nick
{
    my $self = shift;

    return $self->{'nick'};
}

sub from
{
    my $self = shift;
    my $newFrom = shift;

    if (defined $newFrom) {
	$self->{'from'} = $newFrom;
    }

    return $self->{'from'};
}

sub authorizedFrom
{
    my $self = shift;

    return $self->{'authorizedFrom'};
}

sub encoding
{
    my $self = shift;

    return $self->{'encoding'};
}

sub addIgnore
{
    my $self = shift;
    my $newIgnore = shift;

    $newIgnore =~ s/[^a-z0-9._-]//gi;

    if (not defined $newIgnore
	or $newIgnore eq "") {
	$self->{'ignore'} = [];	# no argument - clear ignorance list
        $self->send("113 ignorance list flushed");
    } else {
	unshift @{$self->{'ignore'}}, $newIgnore;

        $self->send("113 ignorance increased");
    }
}

sub ignore
{
    my $self = shift;
    my $message = shift;

    foreach (@{$self->{'ignore'}}) {
	if (eval '$message =~ /$_/i') {
	    return 1;
	}
    }

    return 0;
}

sub set_encoding
{
    my $self = shift;
    my $encoding = shift;

    $self->{'encoding'} = $encoding;

    return 0;
}

sub clientinfo {
  my $self = shift;

  if (defined($self->{'clientPid'})) {
    return "$self->{'clientPid'}";
  } else {
    return "unknown";
  }
}

sub send
{
    my $self = shift;
    my $message = shift;
    my $noIgnore = shift;

    $self->{'bytesOut'} += length($message);

    $message .= "\r\n";

    $message = from_utf8({ -string => $message, 
			   -charset => $self->encoding()});

    if (not defined $noIgnore and $self->ignore($message)) {
	return 0;
    }

    my $fh = $self->{'fileDescriptor'};

    if (defined $self->{'fileDescriptor'}) {
	if (syswrite($fh, $message, length($message)) != length($message)) {
	    logMessage "$self->{'nick'} bad write ($!)\n";
	    $self->{'fileDescriptor'} = undef;
	    $self->handleCommand(".x");
	}
	if ($debug > 1) {
	    logMessage "$self->{'nick'} MSG: $message";
	} elsif ($debug) {
	    if ($message =~ /^\d{3} /) {
		logMessage "$self->{'nick'} MSG: $message";
	    }
	}
    }

    return 1;
}

sub showFile
{
    my $self = shift;
    my $file = shift;

    if (open(FILE, $file)) {
	while (<FILE>) {
	    chomp;
	    my $cont = "-";
	    if (eof FILE) {
		$cont = " ";
	    }
	    $self->send("100$cont$_");
	}
	close(FILE);
    }
}

sub handleCommand
{
    my $self = shift;
    my $command = shift;

    $self->{'bytesIn'} += length($command);

    # check message length, truncate if oversized.

    if (length($command) > $maxMessageLength) {
	$self->send("301 Message too long, truncated");
	$command = substr($command, 0, $maxMessageLength);
    }

    # log the message -- message text is logged only if $debug is larger
    # than 1

    if ($debug > 1) {
	logMessage "$self->{'nick'} CMD: $command\n";
    } elsif ($debug) {
	my $logText = $command;
	if ($command =~ /^\.m (\S+) /) {
	    $logText = ".m $1 (talk)";
	} elsif ($command !~ /^\./) {
	    $logText = "(talk)";
	}
	logMessage "$self->{'nick'} CMD: $logText\n";
    }

    $command =~ s/\s*$//;		# remove trailing white space
    return if ($command =~ /^\s*$/);	# ignore empty lines.


    ####################################################################
    # message parsing starts here
    ####################################################################

    # first, check for commands which are allowed without logging in

    if ($command =~ /^\.h/) {

	$self->cmdHelp();

	return;

    } elsif ($command =~ /^\.x *(.*)/) {

	$self->cmdExit($1);

	return;

    } elsif ($command =~ /^\.l\s+(\S+)\s+(\S+)\s*(-?[0-9.]*)/) {

	my ($nick, $from, $channel) = ($1, $2, $3);

	if ($channel !~ /^-?\d{1,5}$/) {
	    $channel = 0;
	}

	$self->cmdLogin($nick, $from, $channel);
	
	return;
    } elsif ($command =~ /^\.e (.*)/) {

        my $encoding = $1;

        if(utf8_supported_charset($encoding)) {
            $self->set_encoding($encoding);
            $self->send("269 Encoding set to $encoding");
	} else {
            $self->send("469 I'm very sorry, $encoding is not known to this system, try .E for a list");
        }

        return;
    } elsif ($command =~ /^\.E/) {

        my @encodings = utf8_supported_charset;
        my $tmpstring = "Known encodings: ";
        foreach(@encodings) {
          if(length($tmpstring)+length($_)>65) {
            $self->send("169-$tmpstring");
            $tmpstring = "";
          }
          $tmpstring .= $_." ";
        }
        $self->send("169 $tmpstring");


        return;
    }


    # all other commands require the client to first log in.

    if (not $self->{'loggedIn'}) {
	$self->send("403 Please log in. Type .h for help");
	return;
    }

    # check for remaining commands

    if ($command =~ /^\.n *(\S+)/) {

	$self->resetIdleTime();

	$self->cmdChangeNick($1);
	 
    } elsif ($command =~ /^\.f *(.+)/) {

	$self->cmdChangeFrom($1);

    } elsif ($command =~ /^\.t *(.*)/) {

	$self->cmdSetChannelTopic($1);

    } elsif ($command =~ /^\.m *([^:\s]+):? (.+)$/) {

	my ($to, $message) = ($1, $2);

	if ($self->cmdSendPrivateMessage($to, $message)
	    and (lc($to) ne lc($self->nick))) {

	    $self->resetIdleTime();
	}


    } elsif ($command =~ /^\.p *(\S+)/) {

	$self->cmdShowProtocol($1);

	return;

    } elsif ($command =~ /^\.s *(\S*)/) {

	$self->cmdShowClientOrChannel($1);

    } elsif ($command =~ /^\.S *(-?\d*)/) {

	$self->cmdShowNicks($1);

    } elsif ($command =~ /^\.c *(-?\d{1,4})$/i) {

	if ($self->cmdJoinChannel(int($1))) {
	    $self->resetIdleTime();
	}

    } elsif ($command =~ /^\.i *(.*)/) {

	$self->cmdIgnore($1);

    } elsif ($command =~ /^\.a *(.+)/) {

	my $action = $1;

	if (not defined $self->channel) {
	    $self->send("100 Not joined to a channel");
	} else {
	    my $sentTo
		= $self->channel->send("118 ".$self->nick." ".$action,
				       $self);
		
	    $self->resetIdleTime();

	    if ($sentTo == 0) {
		$self->send("100 Nobody sees what you do");
	    }
	}

    } elsif ($command =~ /^\.o *(.+)/) {

	my $thoughts = $1;

        if (not defined $self->channel) {
            $self->send("100 Not joined to a channel");
        } else {

	my $sentTo
		= $self->channel->send("124 ".$self->nick." .o( ".$thoughts." )",
					$self);

	$self->resetIdleTime();

        if ($sentTo == 0) {
		$self->send("100 Nobody sees what you do");
	}

	}

    } elsif ($command =~ /^\.u\s*(.*?) *(\S*)\s*$/) {

	$self->resetIdleTime();

	$self->cmdURL($1, $2);

    } elsif ($command =~ /^\./ 
	     and $command !~ /^\.\../) {

	$self->send("402 Bad command");

    } else {

	$self->resetIdleTime();

	if (not defined $self->channel) {

	    $self->send("100 Not joined to a channel");

	} else {

	    my $sentTo
		= $self ->channel->send("<".$self->nick."> ".$command,
					$self);

	    if ($sentTo == 0) {
		$self->send("100 Nobody hears you");
	    }
	}
    }
}

sub readClientData
{
    my $self = shift;
    my $fh = $self->{'fileDescriptor'};
    my $buf;

    my $bytesRead = sysread($fh, $buf, 1024);
    if ($bytesRead <= 0) {
	if ($bytesRead < 0) {
	    logMessage "$self->{'nick'} bad read ($!)\n";
	}
	$self->handleCommand(".x");
	return;
    }

    if ($debug > 3) {
	logMessage "read ", length($buf), " bytes\n";
    }

    if (defined $self->{'buf'}) {
	$buf = $self->{'buf'} . $buf;
    }

    while ($buf =~ s/^([^\r\n]+)\r?\n//) {
	my $command = $1;

	$command = to_utf8({ -string => $command, 
			     -charset => $self->encoding()});
	# filtering out these should be fine
	$command =~ s/[\000-\037]/?/g;		# remove control chars

	# whereas these are a problem for Unicode, and shouldn't hurt anyways
#	$command =~ s/[\200-\237]/?/g;		# remove control chars

	# and nobody uses telnet anymore, right?
#	$command =~ s/\377[\360-\372]//g;	# remove telnet options
#	$command =~ s/\377[\373-\376].//g;

	$self->handleCommand($command);
    }

    if (length($buf) > 0) {
	$self->{'buf'} = $buf;
    } else {
	$self->{'buf'} = undef;
    }
}

sub stats {
    my $self = shift;
    my $recipient = shift;

    $recipient->send("117 $self->{'nick'} stats sent "
		     . $self->{'bytesIn'} . " received "
		     . $self->{'bytesOut'} . " online "
		     . deltaTimeString(time - $self->{'loginTime'})
		     . " idle "
		     . deltaTimeString($self->idleTime()));
}

sub idleTime {
    my $self = shift;

    return time - $self->{'lastMessageTime'};
}

sub resetIdleTime {
    my $self = shift;

    $self->{'lastMessageTime'} = time;
    $self->{'idleWarned'} = 0;
}

sub idleWarned {
    my $self = shift;
    my $newWarned = shift;

    if (defined $newWarned) {
	$self->{'idleWarned'} = $newWarned;
    }

    return $self->{'idleWarned'};
}

sub isRegistered {
    my $self = shift;

    return (($self->{'authorizedNick'} ne '') ? 1 : 0);
}

sub cmdChangeNick {
    my $self = shift;
    my $nick = shift;
    my $quiet = shift or 0;

    $nick = substr($nick, 0, $maxNickLength);
    if ($nick !~ /^[a-z0-9][a-z0-9._-]*$/i) {

	$self->send("401 Bad characters in nick name");
	return 0;
    }

    if ($nick =~ /^[0-9]/i) {

	$self->send("401 Invalid nick name (must not begin with digit) - Nick not changed");
	return 0;
    }

    if ($nick !~ /^...*/) {
	$self->send("401 Nick name too short.");
	return 0;
    }

#    print "changing nick for $self->{'nick'} to $nick: ";
    if (lc($nick) ne lc($self->{'authorizedNick'})
	and isReservedNick($nick)) {
      $self->send("415 Nickname reserved");
#      print "not authorized\n";
      return 0;
    }
#    print "authorization ok\n";

    my $exists = find($nick);
    if ($exists) {
	# check whether this is a case change.  refuse change if a user
	# with that name already exists or if there would be no change.
	if ((lc($self->{'nick'}) ne lc($exists->{'nick'}))
	    or ($self->{'nick'} eq $nick)) {
	    $self->send("411 Nickname is already in use");
	    return 0;
	}
    }

    my $oldNick = $self->{'nick'};
    Completion::remove("${oldNick}:");
    Completion::add("${nick}:");
    $self->{'nick'} = $nick;
    $Extent{$nick} = $self;
    delete $Extent{$oldNick};

    if (not $quiet) {
	Chatserver::send("241 $oldNick $nick - nick changed");
    }

    return 1;
}

my %nickActions;

sub protEnt {
    my $self = shift;
    my $action = shift;
    my $nick = lc $self->{'nick'};
    
    if (not defined $nickActions{$nick}) {
	$nickActions{$nick} = {};
    }

    $nickActions{$nick}->{$action} = timeStamp;
}    

sub cmdShowProtocol {
    my $self = shift;
    my $nick = lc shift;

    if (defined $nickActions{$nick}) {
	$self->send("123 $nick " . join(" ", %{$nickActions{$nick}}));
    } else {
	$self->send("412 $nick not found (never logged in or out?)");
    }
}

sub cmdShowClientOrChannel {
    my $self = shift;
    my $arg = shift;

    if ($arg eq "*") {
	$arg = $self->channel->number;
    }

    if ($arg =~ /^(-?\d*)$/) {

	my $showOnlyChannel = ($1 eq "") ? undef : int($1);

	if (defined $showOnlyChannel) {
	    if (not Channel::defined($showOnlyChannel)) {
		$self->send("413 Channel $1 is not active");
		return;
	    }
	    $showOnlyChannel = Channel::findOrCreate($showOnlyChannel);
	}

	if (not defined($self->channel)
	    or (defined $showOnlyChannel
		and $showOnlyChannel->isInvisible
		and $showOnlyChannel ne $self->channel)) {
	    $self->send("414 Access violation");
	    return;
	}
		     
	$self->send("100 ".
		    sprintf("%5s %-${maxNickLength}s S %-${maxHostLen}s %s",
			    'Chan', 'Nick', 'From', 'Idle'));
	my $nClients = 0;
	my $nVisible = 0;
	my %notShown;

	foreach (
                 sort { 
                     not defined $Extent{$a}->{'channel'}
                     or not defined $Extent{$b}->{'channel'}
                     or (($Extent{$a}->{'channel'}->number <=> $Extent{$b}->{'channel'}->number))
                         or (lc($Extent{$a}->{'nick'}) cmp lc($Extent{$b}->{'nick'}))
                         }
                 keys %Extent) {
	    my $client = $Extent{$_};
	    $nClients++;
            
            next if (not defined $client->{'channel'});
            
	    next if ($client->{'channel'}->isInvisible
		     and $client->{'channel'} ne $self->{'channel'});

	    next if (defined $showOnlyChannel
		     and ($client->channel ne $showOnlyChannel));

	    if (not defined $showOnlyChannel
		and ($client->{'channel'} ne $self->{'channel'})
		and (length($client->{'channel'}->number) > 1)) {
		$notShown{$client->{'channel'}->number}++;
		next;
	    }
	    
	    if ($client->{'loggedIn'}) {
		$nVisible++;
		my $status = "L";
		if (not $client->isRegistered) {
		    $status = lc($status);
		}
		my $from = "$client->{'from'}";

		if (length($from) > $maxHostLen) {
		    $from = substr($from, 0, $maxHostLen-1) . "*";
		}
		my $idle = deltaTimeString(time - $client->{'lastMessageTime'}); 
		$self->send("110 ".
			    sprintf("%5d %-$maxNickLength.${maxNickLength}s %s %-$maxHostLen.${maxHostLen}s %-3s",
				    $client->{'channel'}->number, 
				    $client->{'nick'},
				    $status, $from, $idle));
	    }
	}

	if (defined $showOnlyChannel) {
	    $self->send("115 " . $showOnlyChannel->number . " " . $showOnlyChannel->topic);
	}

	if (keys %notShown) {
	    $self->send("100 Other active channels/users: "
			. join(", ", 
			       map { $_ . "/" . $notShown{$_} } 
			       sort { $a <=> $b } keys %notShown));
	}
	$self->send(sprintf("100 %d/%d user%s logged on/not shown.  Chatserver up for %s, %d clients served",
			    $nClients, $nClients-$nVisible,
			    (($nClients != 1) ? "s" : ""),
			    deltaTimeString(time - $startTime),
			    $clientCounter));
    } else {
	my $client = find($arg);

	if (not defined $client) {
	    $self->send("412 bad nick name $client");
	} else {
	    $self->send("116 "
			. $client->nick . " "
                       # . $client->authorizedNick . " " 
			. $client->from . " "
			. $client->authorizedFrom . " "
			. $client->isRegistered . " "
			. $client->clientinfo . " "
			. $client->stats($self));
	   #foreach(keys %client) {$self->send( "116 $self{$_} : $_\n");}
	}
    }
}

sub cmdShowNicks {
    my $self = shift;
    my $channelName = shift;
    my @nicks = sort keys %Extent;

    if ($channelName ne "") {
	if (Channel::defined($channelName)) {

	    my $channel = Channel::findOrCreate($channelName);

	    if (not defined($self->channel)
		or ($channel->isInvisible
		    and $channel ne $self->channel)) {
		$self->send("414 Access violation");
		return;
	    }
	    
	    @nicks = grep { $Extent{$_}->channel eq $channel } @nicks;
	} else {
	    @nicks = ();
	}
    } else {
	$channelName = "*";
    }

    $self->send("119 $channelName " . join(" ", @nicks), 1);

    return 0;
}

sub cmdSendPrivateMessage {
    my $self = shift;
    my ($to, $message) = @_;

    foreach (keys %Extent) {

	if (lc($_) eq lc($to)) {
	    $Extent{$_}->send("*$self->{'nick'}* $message");
	    return 1;
	}
    }

    $self->send("412 Bad nickname, message not sent");

    return 0;
}

sub cmdJoinChannel {
    my $self = shift;
    my $channel = shift;
    my $newChannel = Channel::findOrCreate($channel);

    if ($self->{'channel'} ne $newChannel) {

	$self->{'channel'}->leave($self);
	$newChannel->join($self);
	$self->{'channel'} = $newChannel;

	return 1;
    } else {
	$self->send("304 Already in that channel");
	return 0;
    }
}

sub cmdIgnore {
    my $self = shift;
    my $string = shift;

    $self->addIgnore($string);
}

sub cmdSetChannelTopic {
    my $self = shift;
    my $topic = shift;

    if (length($topic) > $maxTopicLen) {
	$self->send("302 Topic too long, maximum is $maxTopicLen characters");
    } elsif ($topic eq "") {
	$self->send("115 " . $self->channel->name . " " 
		    . $self->channel->topic);
    } else {
	$self->channel->topic($self, $topic);

	$self->resetIdleTime();
    }
}

sub cmdLogin {
    my $self = shift;
    my ($nick, $from, $channel) = @_;

    if ($self->{'loggedIn'}) {
	$self->send("404 Already logged in");
	return;
    }

    if (($nick eq $self->{'authorizedNick'}) and defined $Extent{$nick}) {
	$Extent{$nick}->handleCommand('.x');
    }

    if (find($nick)) {
	$self->send("411 Nickname is already in use");
	return;
    }

    if (not $self->cmdChangeNick($nick, 1)) {
	return;
    }

    $self->{'loggedIn'} = 1;
    $self->from($from);

    my $message = "$self->{'nick'} ($self->{'authorizedFrom'}) entered the chat";
  Chatserver::send("211 $message", $self);
    $self->send("212 $message");

    if ($channel eq "") {
	$channel = 0;
    }
    $self->{'channel'} = Channel::findOrCreate($channel)->join($self);

    $self->protEnt("login");
}

open(URLMAP, ">>$urlMapFile")
    || warn "$0: can't open $urlMapFile: $!\n";

autoflush URLMAP 1;

my $id = 1;

if (open(URLID, $urlIDFile)) {
    $id = int scalar <URLID>;
    close(URLID);
}

my @savedURLs;

sub cmdURL {
    my $self = shift;
    my ($description, $url) = @_;

    if ($description eq "" and $url eq "") {
	foreach (@savedURLs) {
	    $self->send("122 " . join(" ", $_->[0], $_->[1], $_->[2], $_->[3]));
	}
	return;
    }

    if ($url !~ m-^((ftp|https?|gopher|finger|telnet|ldap|sip|mailto|rtsp|iks)://.*\..*)$-) {
	$self->send("402 Invalid URL");
	return;
    }

    if ($url =~ m-http://vchat.berlin.ccc.de/rd/- && $url =~ m-https://vchat.berlin.ccc.de/rd/-) {
	$self->send("402 Invalid URL (can't self-reference)");
	return;
    }

    if (($url !~ m@^[a-z]+://.*?([-a-z0-9]*?\.[a-z0-9]*?)(:\d+|)/@)
	&& ($url !~ m@^[a-z]+://.*?([-a-z0-9]*?\.[a-z0-9]*?)(:\d+|)$@)) {
	$self->send("402 Invalid URL (domain not found)");
	return;
    }

    foreach (@savedURLs) {
	if ($_->[4] eq $url) {
	    $self->send("402 duplicate URL (stored as $_->[2])");
	    return;
	}
    }

    my $domain = $1;
    my $key = "${domain}-${id}";
    my $now = time;
    print URLMAP "$now $key ", $self->nick, " $url $description\n";
    my $mappedURL = "https://vchat.berlin.ccc.de/rd/${key}";

    if (scalar @savedURLs == 20) {
	shift @savedURLs;
    }

    push @savedURLs, [ strftime("%H:%M", localtime $now), $self->nick, $mappedURL, $description, $url ];

    if ($description ne "") {
	$description .= " ";
    }

    $id++;

    if (open(URLID, ">$urlIDFile")) {
	print URLID $id, "\n";
	close(URLID);
    } else {
	warn "$0: can't write to $urlIDFile: $!\n";
    }

    $self->channel->send("[". $self->nick ."] $description$mappedURL");
}

sub cmdHelp {
    my $self = shift;


	$self->send(
"100-This is a multi-party chat system.  People who are on one channel\r
100-see all text entered by other people on that channel.\r
100-\r
100-Commands:\r
100-.s [<channel>|<nick>]        Show status information about channels/users\r
100-.p <nick>                    Show last login/logout for <nick>\r
100-.c <chan>                    Change to channel with number <chan>\r
100-.m <nick> <msg>              Send private message to <nick>\r
100-.a <something>               Do <something>\r
100-.l <nick> <from> [<channel>] Log in (performed automatically by client)\r
100-.n <nick>                    Change nickname to <nick>\r
100-.f <from>                    Change \"From\" string\r
100-.i [<string>]                Add <string> to your ignorance list or flush\r
100-                             ignorance list if <string> is not given.\r
100-.u [<description>] <url>     Abbreviate <url> and put it to the public\r
100-                             URL list as well as to the current channel.\r
100-                             https://vchat.berlin.ccc.de/rd/0 has the list\r
100-.e [encoding]                Set character set encoding of your client.\r
100-.E                           Show list of known character set encodings.\r
100-.t [<topic>]                 Show/set channel topic\r
100-.x [<reason>]                Exit\r
100-.h                           You just found out what this does.\r
100-\r
100 Problem reports may be directed to chef\@mux.berlin.ccc.de");

}

sub cmdExit {
    my $self = shift;
    my $reason = shift;


    return if ($self->{'leaving'});

    $self->{'leaving'} = 1;

    if (defined $self->channel) {
	$self->channel->leave($self);
    }

    unlink("$nicksDir/$self->{'nick'}".":");
    if ($self->{'loggedIn'}) {
      Chatserver::send("221 $self->{'nick'} left the chat"
		       . ($reason ne "" ? " ($reason)" : ""));
	$self->stats(Chatserver::instance());
    }
    if (defined $self->{'fileDescriptor'}) {
	close($self->{'fileDescriptor'});
    }
    delete $Extent{$self->{'nick'}};
    $self->protEnt("logout");
}

sub cmdChangeFrom {
    my $self = shift;
    my $newFrom = shift;

    if (length($newFrom) > $maxHostLen) {
	$self->send("302 From too long");
	return;
    }

    if ($newFrom =~ /\s/) {
	$self->send("401 Bad characters in from string");
	return;
    }

    $self->from($newFrom);
}

1;
