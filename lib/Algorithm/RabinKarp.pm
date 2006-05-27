package Algorithm::RabinKarp;

use warnings;
use strict;

use UNIVERSAL;

use constant BASE => 256;

use constant MOD => int(2**31 / BASE - 1);

our $VERSION = "0.37";

=head1 NAME

Algorithm::RabinKarp - Rabin-Karp streaming hash

=head1 SYNOPSIS

  my $text = "A do run run run, a do run run";
  my $kgram = Algorithm::RabinKarp->new($window, $text);

or

  my $kgram2 = Algorithm::RabinKarp->new($window, $fh);

or
  my $kgram3 = Algorithm::RabinKarp->new($window, sub {
    ...
    return $num, $position;
  });
  
  my ($hash, $start_position, $end_position) = $kgram->next;
  
  my @values = $kgram->values;
  
  my %occurances; # a dictionary of all kgrams.
  while (my ($hash, @pos) = @{shift @values}) {
    push @{$occurances{$hash}}, \@pos; 
  }
  
  my $needle = Algorithm::RabinKarp->new(6, "needle");
  open my $fh, '<', "haystack.txt";
  my $haystack = Algorithm::RabinKarp->new(6, $fh);
  my $needle_hash = $needle->next;
  
  while (my ($hay_hash, @pos) = $haystack->next) {
    warn "Possible match for 'needle' at @pos" 
      if $needle_hash eq $hay_hash;
  }
  
  
=head1 DESCRIPTION

This is an implementation of Rabin and Karp's streaming hash, as
described in "Winnowing: Local Algorithms for Document Fingerprinting" by
Schleimer, Wilkerson, and Aiken.  Following the suggestion of Schleimer,
I am using their second equation:

  $H[ $c[2..$k + 1] ] = (( $H[ $c[1..$k] ] - $c[1] ** $k ) + $c[$k+1] ) * $k

The results of this hash encodes information about the next k values in
the stream (hense k-gram.) This means for any given stream of length n
integer values (or characters), you will get back n - k + 1 hash
values.

For best results, you will want to create a code generator that filters
your data to remove all unnecessary information. For example, in a large
english document, you should probably remove all white space, as well
as removing all capitalization.

=head1 INTENT

By preprocessing your document with the Rabin Karp hashing algorithm,
it makes it possible to create a "fingerprint" of your document (or documents), 
and then perform multiple searches for fragments contained within your document
database.

Schleimer, Wilkerson, and Aiken suggest preproccessing to remove
unnecessary information (like whitespace), as well as known redundent information
(like, say, copyright notices or other boilerplate that is 'acceptable'.)

They also suggest a post processing pass to reduce data volume, using a technique
called winnowing (see the link at the end of this documentation.)

=head1 METHODS

=over

=item new($k, [FileHandle|Scalar|Coderef] )

Creates a new hash generator.  If you provide a callback function, it must
return the next integer value in the stream. Additionally, you may 
return the original position of the value in the stream (ie, you may have been 
filtering characters out because they're redundant.)

=cut

sub new {
  my $class = shift;
  my $k = shift;
  my $stream; 
  if (defined $_[0] && !ref $_[0]) {
    my $pos = 0;
    my $string = $_[0];
    $stream = sub {
      return if ($pos >= length($string));
      my @ret = (ord(substr($string, $pos, 1)), $pos);
      $pos++;
      return @ret;
    };
  } elsif (ref $_[0] eq 'CODE') {
    $stream = $_[0];
  } elsif (UNIVERSAL::isa($_[0], "IO::Handle") 
           || UNIVERSAL::isa($_[0],"GLOB")) {
    require IO::Handle;
    # The simplest way of getting character position right now.
    my $source = $_[0];
    $stream = sub {
      return if $source->eof;
      (ord($source->getc), tell($source));
    };
  } else {
    die __PACKAGE__." requires its source stream be one of the ".
        "following types: scalar, file handle, coderef, or IO::Handle";
  }
  
  my $rm_k = BASE;
  for (1..$k-1) {
    $rm_k = ($rm_k * BASE) % MOD;
  }
  
  bless { 
    k => $k,
    rm_k => $rm_k, #used to remove the first value in the value buffer.
    vals => [],
    stream => $stream,
  }, ref $class || $class;
}

=item next()

Returns the triple (kgram hash value, start position, end position) for every 
call that can have a hash generated, or () when we have reached the end
of the stream.

C<next()> pulls the first $k from the stream on the first call. Each successive
call to C<next()> has a complexity of O(1).

=cut
sub next {
  my $self = shift;

  # assume, for now, that each value is an integer, or can
  # auto cast to char
  my @values = @{$self->{vals}}; #assume that @values always contains k values
  my $prev = shift @values || [0, undef];
  my $hash = $self->{hash};
  while (@values < $self->{k}) {
    my $nextval = [$self->{stream}->()];
    return unless @$nextval;
    
    push @values, $nextval;
    $hash -= ($prev->[0] * $self->{rm_k}) % MOD;
    $hash += $nextval->[0];
    $hash *= BASE;
    $hash %= MOD;
  }

  $self->{hash} = $hash;
  $self->{vals} = \@values;
  
  return $hash, $values[0]->[1], $values[-1]->[1];
}

=item values

Returns an array containing all C<n - k + 1> hash values contained
within the data stream, and the positions associated with them (in the same
format as yielded by L<next|/METHODS>.)

After calling C<values()> the stream will be completely exhausted, causing 
subsequent calls to C<values> and C<next()> to return C<undef>.

NOTE: You should use C<next> if your source stream is infinite, as values
will greedily attempt to consume all values.

=cut

sub values {
  my $self = shift;
  
  my @values;
  while (my @next = $self->next()) {
    push @values, \@next;
  }
  return @values;
}

=back

=cut

=head1 BUGS

The current multipliers and modulus lead to very poor hash
distributions.  I'll investigate methods of improving this
in future versions.

=head1 SEE ALSO

  "Winnowing: Local Algorithms for Document Fingerprinting"
  L<http://theory.stanford.edu/~aiken/publications/papers/sigmod03.pdf>

=head1 AUTHOR

  Norman Nunley E<lt>nnunley@gmail.comE<gt>
  Nicholas Clark (Who paired with me)

=cut

1;
