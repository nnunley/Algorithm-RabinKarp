package Algorithm::RabinKarp;

use warnings;
use strict;

use constant BASE => 101;

our $VERSION = "0.33";

=head1 NAME

Algorithm::RabinKarp - rabin-karp streaming hash

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
  
  my ($first, $start_position, $end_position) = $kgram->next;
  
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
  my $source;
  if (!ref $_[0]) {
    open $source, '<', \$_[0] 
      or die "Couldn't create a file handle on scalar source: $!";
  } else {
    $source = $_[0];
  }
  my $stream;
  if ($source->isa("IO::Handle") || (ref $source) =~  /^GLOB/) {
    require IO::Handle;
    # The simplest way of getting character position right now.
    my $counter = 0;
    $stream = sub {
      return if $source->eof;
      (ord($source->getc), $counter++);
    };
  } elsif (ref $source eq 'CODE') {
    $stream = $source;
  }
  
  die __PACKAGE__." requires either a scalar, file handle, or coderef"
    unless $source;
    
  if (BASE ** $k <= 0) {
    require bignum;
  }
  
  bless { 
    k => $k,
    rm_k => BASE ** $k, #used to remove the first value in the value buffer.
    vals => [],
    stream => $stream,
  }, ref $class || $class;
}

=item next()

Returns an array of three values for each call. The first element is
the k-gram hash value.  The second and third elements are the start and
end positions, inclusive, as provided by the generator stream.

C<next()> requires $k iterations to warm up on first call (don't worry, you
don't need to remember to do that, it's handled internally.)  Each successive
call to C<next()> has a complexity of O(1).

=cut
sub next {
  my $self = shift;

  # assume, for now, that each value is an integer, or can
  # auto cast to char
  my @values = @{$self->{vals}}; #assume that @values always contains k values
  my $prev = shift @values || [0, undef];
  my $hash = $self->{hash};
  do {
    my $nextval = [$self->{stream}->()];
    return unless @$nextval;
    
    push @values, $nextval;
    # If someone wants to submit a modulus version of this
    # I would be most grateful.
    $hash -= $prev->[0] * $self->{rm_k};
    $hash += $nextval->[0];
    $hash *= BASE;
  } while (@values < $self->{k});
  #warn join( '', map { chr($_ ) } @values). ' '.$hash;
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

NOTE: You should use C<next> if the stream you are generating hash codes for
is infinite. Failure to do so will yield unexpected results.

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

No explicit guards against overflow have been taken, nor any attempts to
use clever bitwise operators.  I recommend either using small values of
C<k>, or including a 'use bignum' line before before iterating with larger
C<k>s.  In a future version of this module, I will shift to using modulo
arithmetic, which will not have the same sort of overflow problems.

=head1 SEE ALSO

  "Winnowing: Local Algorithms for Document Fingerprinting"
  L<http://theory.stanford.edu/~aiken/publications/papers/sigmod03.pdf>

=head1 AUTHOR

  Norman Nunley E<lt>nnunley@gmail.comE<gt>
  Nicholas Clark (Who paired with me)

=cut

1;
