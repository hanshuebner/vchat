# $Id: Completion.pm,v 1.1 2003/04/08 15:46:04 erdgeist Exp $
#
# $Log: Completion.pm,v $
# Revision 1.1  2003/04/08 15:46:04  erdgeist
# Initial import
#
# Revision 1.1.1.1  2003/04/08 11:58:15  chef
# initial import
#
# Revision 1.1  1999/04/15 20:58:17  hans
# Add completion function for words in the channel topics.
#

package Completion;

use conf;
use strict;

my %words;

sub add {
	foreach (@_) {
		$words{$_} = 1;
		open(FH, ">${completionDir}/$_");
		close(FH);
	}
}

sub remove {
	foreach (@_) {
		undef $words{$_};
		unlink("${completionDir}/$_");
	}
}

1;
