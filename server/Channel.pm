package Channel;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);

use Carp;

use strict;

use Completion;

my %Extent;

sub findOrCreate {
    my $number = shift;

    if (defined $Extent{lc($number)}) {
	return $Extent{lc($number)};
    } else {
	return $Extent{lc($number)} = new Channel($number);
    }
}

sub defined {
    return defined $Extent{lc(shift)};
}

sub new {
    my $class = shift;
    my $number = shift;
    my $self = {};

    bless $self, $class;

    $self->{'number'} = $number;

    $self->{'members'} = {};
    $self->{'topic'} = '';

    $self;
}

sub topic
{
    my $self = shift;
    my $client = shift;
    my $newTopic = shift;

    if (defined $newTopic) {
        if (substr($self->{'topic'}, 0, length($newTopic)) eq $newTopic) {
            $client->send("405 This is already the topic");
        } else {
            $self->{'topic'} = $newTopic . " (" . $client->nick . ")";;
            $self->send("114 " . $client->nick() 
                        . " changed the channel topic to '"
                        . $self->{'topic'} . "'");
        }
    }

    return $self->{'topic'};
}

sub join
{
    my $self = shift;
    my $client = shift;

    return if (defined $self->{'members'}->{$client});

    $self->{'members'}->{$client} = $client;
    $self->send("232 " . $client->nick . " joined channel " . $self->name);

    return $self;
}

sub leave
{
    my $self = shift;
    my $client = shift;

    delete $self->{'members'}->{$client};
    $self->send("231 " . $client->nick . " left channel " . $self->name);
}

sub members
{
    my $self = shift;

    return values %{$self->{'members'}};
}

sub send
{
    my $self = shift;
    my $message = shift;
    my $sender = shift;
    my $members = 0;
    my $sentTo = 0;

    foreach my $client ($self->members) {

	next if (defined $sender and $client eq $sender);

	$members++;
	
	if ($client->send($message)) {
	    $sentTo++;
	}
    }

    return $sentTo;
}
    
sub number
{
    my $self = shift;

    return $self->{'number'};
}

sub name
{
    my $self = shift;

    return $self->{'number'}; # for now
}

sub isInvisible
{
    my $self = shift;

    return $self->number < 0;
}

1;
