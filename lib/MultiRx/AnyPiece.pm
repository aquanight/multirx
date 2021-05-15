use v5.30;
use warnings FATAL => 'all', NONFATAL => qw/exec recursion internal malloc newline experimental deprecated portable/;
no warnings 'once';

use experimental qw/signatures refaliasing declared_refs/;

use Scalar::Util ();
use List::Util ();
use Carp ();

our $VERSION = "0.1";

use Object::Pad;

class MultiRx::AnyPiece implements MultiRx::Piece {
	has @opts;
	has $current = 0;
	
	BUILD {
		@_ or Carp::croak "At least one piece is required";
		grep { !MultiRx::is_piece $_ } @_ and Carp::croak "Invalid piece";
		@opts = @_;
	}
	
	method count { $opts[$current]->count }
	
	method _reset {
		$current = 0;
		$_->reset for @opts;
	}
	
	method _save ($data) {
		$data->{current} = $current;
		$data->{state} = $opts[$current]->save;
	}
	
	method _restore ($data) {
		$current = $data->{current};
		$opts[$current]->restore($data->{state});
		#$backref and $opts[$current]->_want_backref;
	}
	
	method _want_backref () {
		$_->_want_backref for @opts;
	}
	
	method last_captured_line () {
		return $opts[$current];
	}
	
	method next () {
		while ($current <= $#opts) {
			unless (defined $opts[$current]->start) {
				$opts[$current]->reset($self->start);
			}
			my $r = $opts[$current]->next;
			if ($r//1) {
				return $r;
			}
			else {
				$opts[$current]->reset;
				++$current;
				next;
			}
		}
		return "";
	}
}

1;