use v5.30;
use warnings FATAL => 'all', NONFATAL => qw/exec recursion internal malloc newline experimental deprecated portable/;
no warnings 'once';

use experimental qw/signatures refaliasing declared_refs/;

use Scalar::Util ();
use List::Util ();
use Carp ();

our $VERSION = "0.1";

use Object::Pad;

my sub parse_piece (@params) {
	my @pieces;
	PARAM: while (@params) {
		my $key = shift @params;
		if (ref $key) {
			if (Scalar::Util::blessed $key) {
				if ($key->isa("MultiRx::Piece")) {
					push @pieces, $key;
				}
				elsif ($key->isa("MultiRx")) {
					...
				}
				elsif ($key->isa("Regexp")) {
					my $p = MultiRx::SimpleRegexPiece->new($key);
					push @pieces, $p;
				}
				else {
					Carp::croak sprintf("Unrecognized parameter of type '%s'", ref $key);
				}
			}
			elsif (ref $key eq "ARRAY") {
				my @seq = __SUB__->($key->@*);
				my $p = MultiRx::SequencePiece->new(@seq);
				push @pieces, $p;
			}
			else {
				Carp::croak sprintf("Unrecognized parameter of type '%s'", ref $key);
			}
		}
		else {
			if ($key eq 'repeat') {
				my \@repeat = shift @params;
				my $piece = __SUB__->(shift @repeat);
				my $mode = shift @repeat;
				my $min;
				my $max;
				if (Scalar::Util::looks_like_number $mode) {
					$min = $mode;
					$mode = undef;
				}
				else {
					$mode =~ m/^(?:lazy|atomic)$/ or Carp::croak "Unrecognized mode '$mode'";
					$min = shift @repeat;
				}
				$max = shift @repeat;
				if ($min eq '+') {
					defined $max and Carp::croak "Invalid minimum value";
					$min = 1;
					$max = undef;
				}
				elsif ($min eq '*') {
					defined $max and Carp::croak "Invalid minimum value";
					$min = 0;
					$max = undef;
				}
				elsif ($min eq '?') {
					defined $max and Carp::croak "Invalid minimum value";
					$min = 0;
					$max = 1;
				}
				else {
					Scalar::Util::looks_like_number $min or Carp::croak "Invalid minimum value";
					if (defined $max) {
						Scalar::Util::looks_like_number $max or Carp::croak "Invalid maximum value";
					}
				}
				my $p = ($mode eq 'lazy' ? "MultiRx::RepeatPiece" : "MultiRx::LazyRepeatPiece" )->new($piece, $min, $max);
				if ($mode eq "atomic") {
					$p = MultiRx::AtomicPiece->new($p);
				}
				push @pieces, $p;
			}
			elsif ($key eq 'any') {
				my @any = __SUB__->((shift @params)->@*);
				my $p = MultiRx::AnyPiece->new(@any);
				push @pieces, $p;
			}
			elsif ($key eq 'atomic') {
				my $piece = __SUB__->(shift @params);
				my $p = MultiRx::AtomicPiece->new($piece);
				push @pieces, $p;
			}
			elsif ($key eq 'capture') {
				my $piece = __SUB__->(shift @params);
				my $p = MultiRx::CapturePiece->new($piece);
				push @pieces, $p;
			}
			elsif ($key eq 'assert') {
				my $piece = __SUB__->(shift @params);
				my $p = MultiRx::AssertPiece->new($piece, 1);
				push @pieces, $p;
			}
			elsif ($key eq 'not') {
				my $piece = __SUB__->(shift @params);
				my $p = MultiRx::AssertPiece->new($piece, "");
				push @pieces, $p;
			}
			elsif ($key =~ m/^\*/) {
				my $p = MultiRx::VerbPiece->new(split /:/, $' );
			}
			else {
				Carp::croak "Unrecognized operator '$key'";
			}
		}
	}
	return @pieces;
}

class MultiRx {
	sub is_piece ($piece) {
		Scalar::Util::blessed $piece and $piece->DOES("MultiRx::Piece");
		#print STDERR "Checking $piece";
		unless (Scalar::Util::blessed $piece) {
			#say STDERR "... not blessed";
			return "";
		}
		unless ($piece->isa("Object::Pad::UNIVERSAL")) {
			#say STDERR "... not a Object::Pad class object";
			return "";
		}
		my $meta = $piece->META;
		unless (grep { $_->name eq "MultiRx::Piece" } $meta->roles)
		{
			#say STDERR "... Missing role";
			return "";
		}
		#unless ($piece->DOES("MultiRx::Piece")) {
		#	say STDERR "... Missing role";
		#	return "";
		#}
		#say STDERR "... ok";
		return 1;
	}
	
	has $root :reader(ROOT);
	has $done = undef;
	has @input;
	has @captures;
	
	has $mark :mutator(MARK);
	has $error :mutator(ERROR);
	
	has %marks;
	
	method _putmark ($mark, $pos) {
		my $prevpos = $marks{$mark};
		$marks{$mark} = $pos;
		return $prevpos;
	}
	
	BUILD (@pieces) {
		my ($seq) = parse_piece \@pieces;
		$root = $seq;
		$root->set_source($self);
		$mark = undef;
		$error = undef;
	}
	
	method _add_capture ($piece) {
		is_piece $piece or Carp::croak "Piece required";
		push @captures, $piece;
	}
	
	method get_capture ($index) {
		$index >= 0 or Carp::croak "Invalid capture position";
		$captures[$index];
	}
	
	# There are two ways to use a multirx object:
	# -> Incremental input, pushing lines one or more at a time.
	# -> Slurp input: presenting the entire input set in a single piece.
	# Both however have the same usage pattern:
	# Call ->add_input to supply the input.
	# Call ->finish_input to mark the end of the input.

	method add_input (@lines) {
		if ($self->is_closed) {
			# The end of input has already been signaled: this is an error.
			Carp::croak "Input already closed (by finish_input): call reset first";
		}
		for my $line (@lines) {
			unless (defined $line) {
				$line = "";
				Carp::carp "Uninitialized value in add_input";
			}
		}
		push @input, @lines;
		if (defined $done) {
			return $done;
		}
		else {
			return $self->next;
		}
	}
	
	method input_available($index) {
		return $#input >= $index;
	}
	
	method get_input (@indices) {
		if (wantarray) {
			return map { $input[$_] } @indices;
		}
		else {
			@indices == 1 or Carp::carp "Use of multiple indices to get_input in scalar context";
			return $input[shift @indices];
		}
	}

	method finish_input () {
		push @input, undef;
		if (defined $done) {
			return $done;
		}
		else {
			return $self->next;
		}
	}
	
	method is_closed () { $#input >= 0 && !defined $input[-1]; }
	
	method start { $root->start; }
	method count { $root->count; }
	method end   { $root->end;   }
	
	method reset () {
		$mark = undef;
		$error = undef;
		$root->reset;
		undef @input;
		$done = undef;
	}
	
	method next () {
		unless (defined $root->start) {
			$root->reset(0);
		}
		if (defined $done) {
			if ($done) {
				$mark = undef;
				$error = undef;
				my $next = $root->end;
				$root->reset($next);
				$done = undef;
				# Now ready to attempt a new match.
			}
			else {
				# The only way $done is defined and false is if there are
				# no more possible matches.
				# Usually this is because we've hit the end of input
				# but it can also happen early due to backtracking verbs.
				if (defined $mark || defined $error) {
					$mark = "";
					$error ||= 1;
				}
				return "";
			}
		}
		ATTEMPT: {
			# $done should now be undef here.
			# Wrap ->next in eval {} because backtrack verbs use die()s to
			# break out of match trees.
			my $r = eval { $root->next };
			if (is_piece $@) {
				return $@->_verb_bt($self);
			}
			elsif ($@) {
				die $@; # Rethrow
			}
			if (!defined $r) {
				return undef;
			}
			elsif ($r) {
				if (defined $mark || defined $error) {
					$error = "";
				}
				return $done = 1;
			}
			else {
				unless (defined $input[$root->start]) {
					# End of input reached.
					if (defined $mark || defined $error) {
						$mark = "";
						$error ||= 1;
					}
					return $done = "";
				}
				$root->reset($root->start + 1);
				redo ATTEMPT;
			}
		}
	}
}

require MultiRx::Piece;
require MultiRx::SimpleRegexPiece;
require MultiRx::SequencePiece;
require MultiRx::RepeatPiece;
require MultiRx::LazyRepeatPiece;
require MultiRx::AnyPiece;
require MultiRx::AtomicPiece;
require MultiRx::AssertPiece;
#require MultiRx::VerbPiece;

1;