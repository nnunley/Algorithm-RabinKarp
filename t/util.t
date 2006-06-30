#! perl

use strict;
use warnings;

use Test::More tests => 20;
use IO::Handle;



use Algorithm::RabinKarp::Util qw( filter_regexp stream_fh );

my $str = "Unbroken";

{
	open my $fh, '<', \$str or die "Oh well: $!";
	ok my $gen = stream_fh($fh);

	my $c = 0;
	while (my ($v, $p) = $gen->()) {
		is $p, $c, "Right position";	
		is chr($v), substr($str, $c, 1), 'Right character';
		$c++
	}

}

{
	open my $fh, '<', \$str or die "Oh well: $!";
	ok my $gen = filter_regexp( qr{[Un]}, stream_fh($fh) ), "Created filter";

  my ($s, @pos);
  while (my ($v, $p) = $gen->()) {
    $s .= chr($v);
    push @pos, $p;
  }
  is $s, 'broke', "String has the characters U and n filtered.";
  is_deeply \@pos, [ 2, 3, 4, 5 , 6 ], 'All character positions are correct';
}
