#!/usr/bin/perl

# chatserver.pl - Multi-Party chat server.

# This is a TCP/IP based chat server.  To participate in the chat,
# clients connect to this server using a TCP/IP connection.  Messages
# received from a client are sent out to all other clients who are
# logged to the same channel.  Special messages which are meant to be
# interpreted by the server rather than distributed to the channel
# participants are begin with a dot ('.').

# The protocol is kept human readable so that people can participate
# without having to use special client software simply by using telnet
# to the server port.

# Clients need to first log in using the '.l' command.

# $Header: /Users/hans/Downloads/cvsroot/vchat/server/chatserver.pl,v 1.1 2003/04/08 15:46:04 erdgeist Exp $

# $Log: chatserver.pl,v $
# Revision 1.1  2003/04/08 15:46:04  erdgeist
# Initial import
#
# Revision 1.1.1.1  2003/04/08 11:58:15  chef
# initial import
#
#
# Revisuin 1.41  2002/10/03 18:00:00 chef
# Anti-Idle-Kick nur bei > 7 User in .c 0
#
# Revision 1.40  2002/02/08 21:40:05  hans
# .p jetzt in einem per-nick-hash
#
# Revision 1.39  2001/12/16 19:01:19  hans
# Manager-Zeugs vollstaendig rausgeworfen
#
# Revision 1.38  2001/12/10 20:04:55  hans
# Fix pid wraparound problem
#
# Revision 1.37  2001/11/14 06:55:08  hans
# pids/nickdir loeschen und neu anlegen beim start
#
# Revision 1.36  2001/11/07 13:45:30  hans
# *** empty log message ***
#
# Revision 1.35  2001/10/26 22:47:36  hans
# Add -f flag to pid/nick file cleanup upon start.
#
# Revision 1.34  2001/10/20 10:46:14  hans
# Remove old PID files upon startup
#
# Revision 1.33  2001/10/13 11:28:56  hans
# Exit select loop after one client's input has been handled.  This is
# supposed to fix the long-outstanding bug which made the server crash
# once a day.
#
# Revision 1.32  2001/08/24 22:04:18  hans
# Kompromiss mit Count.  Man muss jetzt nur alle vier Minuten gucken, ob sich
# im vchat was interessantes getan hat.
#
# Revision 1.31  2001/07/13 21:13:37  hans
# Chatserver::send() erlaubt nunmehr, einen client auszuschliessen.
#
# Revision 1.30  2001/07/11 12:14:10  hans
# SSL-Geraffel raus
#
# Revision 1.29  2001/07/09 11:20:46  hans
# Add SSL_verify_depth to IO::Socket::SSL initialization parameters
#
# Revision 1.28  2001/07/04 15:08:10  hans
# SSL-Stuff added
#
# Revision 1.27  2001/04/23 21:01:36  hans
# Idle warning completed
#
# Revision 1.26  2001/04/23 21:00:20  hans
# Implement client limit to prevent server crashes
#
# Revision 1.25  2001/04/10 09:42:08  hans
# Warn user before Channel 0 timeout occurs.
#
# Revision 1.24  2001/02/23 07:00:18  hans
# Additional check to defend against dead clients?!
#
# Revision 1.23  2000/06/10 22:50:26  hans
# Idle in Kanal 23, Timeout nach 23 Minuten.  So viel Spass muss sein 8)
#
# Revision 1.22  2000/06/10 18:14:46  hans
# Only idle-kick on channel 0
#
# Revision 1.21  2000/06/10 17:59:01  hans
# Auto-Idle-Kick eingebaut.  Flatrate ist zu billig geworden 8)
#
# Revision 1.20  2000/01/01 23:12:14  hans
# Managerport abgeschaltet (firewall no longer active on berlin.ccc.de)
#
# Revision 1.19  1999/04/15 20:58:18  hans
# Add completion function for words in the channel topics.
#
# Revision 1.18  1998/08/15 19:42:31  hans
# Suppress statistics.
#
# Revision 1.17  1998/07/27 23:12:17  hans
# Make Chatserver a singleton with a send subroutine to unify broadcast
# handling.
#
# Revision 1.16  1998/07/27 22:43:24  hans
# Defend against clients dying during the processing of a message in
# other channels during one select run.
#
# Revision 1.15  1998/07/26 19:27:47  hans
# Guard against accept() returning undef.
# Rearrange for emacs perl mode sanity.
# Suppress 'bad read' messages.
#
# Revision 1.14  1998/07/04 16:41:48  hans
# Fix up logging.  Only broadcast messages are written to the log file.
# Fix .t - If used without an argument, the current channel topic is shown.
# Allow for a channel other than 0 to be joined when logging in with .l.
#
# Revision 1.13  1998/07/04 00:03:22  hans
# Moved more functionality into the Channel object.  Messages are now
# generally sent via the send() subroutine, which is implemented by both
# Channel and Client objects.  Logging is performed in the new
# Chatserver class, which is implemented in chatserver.pl.  Joining and
# leaving a channel is performed by the Channel class.  Channel topics
# are partially implemented (.t command).
#
# Revision 1.12  1998/05/02 13:03:11  hans
# Completely reworked version.
# Modularized Client/Channel/Manager
#
# Revision 1.11  1998/04/23 09:06:45  hans
# Negative Kanalnummern nicht im Protokoll mitloggen.
#
# Revision 1.10  1998/04/21 11:42:02  hans
# Mithoeren ist nicht mehr moeglich, wenn man nicht eingelogged ist.
#
# Revision 1.9  1998/04/14 00:33:21  hans
# idle field for clients added.
# show only one host name (localhost=>FROM specification, other=>peer name)
# negative channels added, will not be shown in .s
#
# Revision 1.8  1998/04/13 23:13:05  hans
# pass lines beginning with .. to the channel. (djenia)
#
# Revision 1.7  1998/04/13 22:05:31  hans
# Added system paths
# Print $etcDir/motd to clients connecting.
#
# Revision 1.6  1998/04/13 21:40:39  hans
# moving to cvs
#
# Revision 1.5  1998/03/09 11:52:24  hans
# Cosmetic changes.
#
# Revision 1.4  1998/03/07 21:58:24  hans
# Manager port added.
# Structural changes.
# Minor fixes.
#
# Revision 1.3  1998/03/07 19:45:25  hans
# Remove telnet options.
# Fix 'protocol' command.
#

package Chatserver;

use English;
use strict;
use FileHandle;
use IO::Socket;
use Net::hostent;
use POSIX qw(strftime);

use Channel;
use Client;
use Completion;

use conf;

my $instance = {};
bless $instance, "Chatserver";

sub instance
{
    return $instance;
}

sub send
{
    my $message = shift;

    if (ref($message)) {
	$message = shift;
    }

    my $suppressClient = shift;
    my $client;

    # Broadcast the message to all Clients.  Statistics are suppressed
    if ($message !~ /^117/) {
	foreach $client (Client::extent) {
	    $client->send($message)
		unless (defined $suppressClient
			and ($suppressClient eq $client));
	}
    }
}

system("rm -rf $pidsDir $nicksDir");
system("umask 2; mkdir $pidsDir $nicksDir; chmod 777 $pidsDir $nicksDir");

my $clientSocket = IO::Socket::INET->new( Proto     => 'tcp',
					  LocalAddr => '127.0.0.1',
					  LocalPort => $clientPort,
					  Listen    => &SOMAXCONN,
					  Reuse     => 1);

$clientSocket or die "$0: can't setup client listen socket ($!)\n";

print STDERR "$0: accepting chat clients on port $clientPort\n";

$SIG{PIPE} = 'IGNORE';

loop:
while (1) {

    # then set up select set

    my $ready = '';
    vec($ready, fileno($clientSocket), 1) = 1;

    foreach (Client::all()) {
	vec($ready, fileno($_->fileDescriptor), 1) = 1;
    }

    my $count = select($ready, undef, undef, 10);

    my $userInChannelZero=0;
    foreach (Client::all()) {
        if ((defined $_->channel)
            and ($_->channel->number == 0)) {
            $userInChannelZero++;
        }
    }
    if($userInChannelZero>=4) {
      foreach (Client::all()) {
	  if ((defined $_->channel)
	      and ($_->channel->number == 0)) {
	      if ($_->idleTime() > 23*60) {
	      	  $_->handleCommand('.c 23');
	      } elsif ((not $_->idleWarned()) and ($_->idleTime() > 19*60)) {
		  $_->send('305 Still there?');
		  $_->idleWarned(1);
	      }
	  }
      }
    }
    my $newClientFD = undef;
    if (vec($ready, fileno($clientSocket), 1)) {
	$newClientFD = $clientSocket->accept();
    }

    if (defined $newClientFD) {
	if (Client::count() > $maxClients) {
	    print STDERR "rejecting client, limit $maxClients reached\n";
	    $newClientFD->close();
	} else {
	    if (defined $newClientFD) {
		new Client($newClientFD);
	    }
	}
    }

    foreach my $client (Client::all()) {
	next if (not defined $client);	# defend against dead clients

	if (not ref($client)) {
	    warn "$0: got a non-reference in Client::all() (skipped)\n";
	    next;
	}
				
	if (vec($ready, fileno($client->fileDescriptor), 1)) {
	    $client->readClientData;
	    next loop;
	}
    }
}

