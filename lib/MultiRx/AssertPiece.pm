use v5.30;
use warnings FATAL => 'all', NONFATAL => qw/exec recursion internal malloc newline experimental deprecated portable/;
no warnings 'once';

use experimental qw/signatures refaliasing declared_refs/;

use Scalar::Util ();
use List::Util ();
use Carp ();

our $VERSION = "0.1";

use Object::Pad;

class MultiRx::AssertPiece implements MultiRx::Piece {
	has $piece;
	has $want;
	has $done;
	
	BUILD ($p, $want_success) {
		MultiRx::is_piece $p or Carp::croak "Invalid piece";
		$piece = $p;
		$want = !!$want_success;
	}
	
	method count { 0 }
	
	method _reset {
		$piece->reset;
	}
	
	method _save ($data) {
		$data->{piece} = $piece->save;
	}
	
	method _restore ($data) {
		$piece->restore($data->{piece});
	}
	
	method last_captured_line () {
		$want or return undef;
		return $piece;
	}
	
	method _want_backref () {
		# Like atomic pieces, assertions do not internally backtrack. But we still
		# want to pass the signal along just in case.
		$want or return;
		$piece->_want_backref;
	}
	
	method next () {
		if ($done) {
			# Attempt to interally-backtrack. Nope.
			return "";
		}
		else {
			$piece->reset($self->start);
			my $r = $piece->next;
			if (defined $r) {
				$done = 1;
				return (!!$r == !!$want);
			}
			else {
				return undef;
			}
		}
	}
}

1;