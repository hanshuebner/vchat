while (<>) {
    chomp;
    if (m-^// (\S+)-) {
	$type = $1;
    } elsif (/^ {20} +(\S+.*)/) {
	$description .= $1;
    } else {
	if (defined $description) {
	    print sprintf("%-40s = \"%s\"; // %s\n", 
			  "_${type}NameMap[\"$long\"]",
			  $short, $description);
	}
	($junk, $long, $short, $description) = split(/\s+/, $_, 4);
    }
}
