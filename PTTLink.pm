package PTTLink;

# Strict and warnings recommended.
use strict;
use warnings;



sub RptFun {
	my ($mynode, $yournode) = @_;
	my $cmd = "sudo /usr/sbin/asterisk -rx \"rpt fun " . $mynode . " " . "$yournode\"";
#	system($cmd);
}






1;