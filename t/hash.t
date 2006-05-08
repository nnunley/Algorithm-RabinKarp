#! perl

use strict;
use warnings;
use Test::More;


my $source = lc("A do run run run, a do run run");
$source =~ tr[a-z][]cd; #we don't want anything else.
my $k = 5;
my $kgrams =  length($source) - $k + 1;
plan tests => 2 + 3 * $kgrams;

use Algorithm::RabinKarp;

my $kgram = Algorithm::RabinKarp->new($k,$source);
ok my @values = $kgram->values, "We get a kgram hash array";
is @values, $kgrams, "We get length - k + 1 kgram hash values";

#use Data::Dumper; warn Dumper(\%check);
my %kgram_seen;
my %source_seen;

for my $i (0..(length($source)-$k)) {
  my $fragment = substr($source, $i, $k);
  my $occurences = $source_seen{$fragment}++;
  my $kgram = shift @{$values[$i]};
  is $kgram_seen{$kgram}++, $occurences, 
    "$fragment has occurred $occurences times.";
    
  my ($start, $end) = @{$values[$i]};
  is_deeply [$start, $end], [$i, $i + $k - 1], 
    "$fragment position correctly recorded";
  is substr($source, $start, $end - $start + 1 ), $fragment,
    "The recorded offsets correctly select $fragment";
}

