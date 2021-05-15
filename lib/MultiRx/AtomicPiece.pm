use v5.30;
use warnings FATAL => 'all', NONFATAL => qw/exec recursion internal malloc newline experimental deprecated portable/;
no warnings 'once';

use experimental qw/signatures refaliasing declared_refs/;

use Scalar::Util ();
use List::Util ();
use Carp ();

our $VERSION = "0.1";

use Object::Pad;

class MultiRx::AtomicPiece implements MultiRx::Piece {
	has $piece;
	has $done = "";

	BUILD {
		my $p = shift @_;
		MultiRx::is_piece $p or Carp::croak "Invalid piece";
		$piece = $p;
	}
	
	method count { $piece->count }
	
	method _reset {
		$piece->reset;
	}
	
	method _save ($data) {
		$data->{piece} = $piece->save;
	}
	
	method _restore ($data) {
		$piece->restore($data->{piece});
	}
	
	method last_captured_line () { $piece->last_captured_line; }
	
	method _want_backref () {
		# Backref signalling is mainly used to stop certain optimizations during
		# internal backtracking of the triggered piece(s), and atomic groups do not
		# observe internal backtracking. However, I can't be 100% sure it's the only
		# thing it'll be used for, so pass the signal along anyway.
		$piece->_want_backref;
	}
	
	method next () {
		if ($done) {
			# Attempt to internal-backtrack. Nope.
			return "";
		}
		else {
			$piece->reset($self->start);
			my $r = $piece->next;
			if (defined $r) {
				$done = 1;
				return $r;
			}
		}
	}
}

1;