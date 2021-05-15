use v5.30;
use warnings FATAL => 'all', NONFATAL => qw/exec recursion internal malloc newline experimental deprecated portable/;
no warnings 'once';

use experimental qw/signatures refaliasing declared_refs/;

use Scalar::Util ();
use List::Util ();
use Carp ();

our $VERSION = "0.1";

use Object::Pad;

class MultiRx::RepeatPiece implements MultiRx::Piece {
	has $count = undef;
	has $piece :reader;
	has $min :reader;
	has $max :reader;

	has $done :mutator = "";
	has @iterations;
	has %nocount;
	
	method count { $count // 0 }
	
	method _itcount { scalar @iterations }
	
	BUILD {
		my $p = shift @_;
		MultiRx::is_piece $p or Carp::croak "Invalid piece";
		if ($p->isa("MultiRx::AssertPiece")) {
			if ($min > 0) {
				Carp::carp "Quantifier unexpected on zero-length expression";
				$min = 1;
			}
			$max = 1;
		}
		$piece = $p;
		($min, $max) = @_;
	}
	
	method _reset () {
		$count = undef;
		$piece->reset;
		$done = "";
		undef @iterations;
		undef %nocount;
	}
	
	method _save ($data) {
		$piece->save($data->{piece} = {});
		$data->@{qw/count done iterations/} = ($count, $done, [ @iterations ]);
	}
	
	method _restore ($data) {
		($count, $done, @iterations) = ($data->@{qw/count done/}, $data->{iterations}->@*);
		$piece->restore($data->{piece});
	}
	
	method _pushit () {
		my $data = {};
		$piece->save($data);
		push @iterations, $data;
		$piece->reset($self->end);
		$self->backref and $piece->_want_backref;
	}
	
	method _popit () {
		$piece->reset;
		if (@iterations) {
			my $data = pop @iterations;
			$piece->restore($data);
			$self->backref and $piece->_want_backref;
			return 1;
		}
		return "";
	}
	
	method _want_backref () {
		$piece->_want_backref;
	}
	
	method _step_success () {
		# Have we reached our maximum match count?
		if (defined $max && (@iterations + 1) == $max) {
			# Then return successfully now.
			$done = 1;
			return 1;
		}
		$self->_pushit;
		unshift @_, $self;
		goto &next;
	}
	
	method _step_failure () {
		if (@iterations >= $min) {
			# Reinstate the last successful iteration.
			# If we are backtracked, that piece will then be backtracked
			# and then we're back at it.
			$self->_popit;
			$done = 1;
			return 1;
		}
		unless ($self->_popit) {
			# We have run out of possible matches at the first iteration.
			# It's not possible to attain a match at this point unless we
			# have a minimum of 0.
			$done = 1;
			return $min < 1;
		}
		unshift @_, $self;
		goto &_step;
	}
	
	method _step () {
		$count -= $piece->count // 0;
		my $r = $piece->next;
		if ($r // 1) {
			$count += $piece->count;
			if ($r) {
				if ($piece->count < 1) {
					# Matched zero-length. We can produce a successful
					# match regardless of our current count and minimum
					# value. Note that we still keep our minimum in mind,
					# because due to assertions it's possible to construct
					# a regex that can match zero-length but yet isn't a
					# "cannot fail" regex. If we're backtracked, we'll
					# step this piece, maybe get a nonzero-length match,
					# and move on.
					$done = 1;
					return 1;
				}
				unshift @_, $self;
				goto &{$self->can("_step_success")};
				#return $self->_step_succcess;
			}
			return undef;
		}	
		else {
			# No (more) matches possible at this iteration, we need to try something else.
			# First off: if we are in completion range, then we can end successfully.
			unshift @_, $self;
			goto &{$self->can("_step_failure")};
			#return $self->_step_failure;
		}
	}
	
	method _next_backtrack () {
		# We're being backtracked.
		# Note: mode = atomic is not handled here: that's done by wrapping us in an AtomicPiece which will never call back in once
		# lock in a match until a ->reset.
		# Does the last piece have any alternative options?
		unless (defined $piece->start) {
			# This situation happens if we returned a match at
			# repetition count 0. This means we have already exhausted all
			# possible iterations of our piece and had to resort to a zero-
			# length match. At this point, we are literally out of options.
			return "";
		}
		$done = "";
		unshift @_, $self;
		goto &_step;
	}
	
	method _first () {
		# Otherwise, let it begin.
		$piece->reset($self->start);
		unshift @_, $self;
		goto &_step;
	}
	
	method next () {
		if ($done) {
			unshift @_, $self;
			goto &{$self->can("_next_backtrack")};
		}
		if (defined $piece->start) {
			# Resume a match in progress.
			unshift @_, $self;
			goto &_step;
		}
		$count = 0;
		unshift @_, $self;
		goto &{$self->can("_first")};
	}
	
	method last_captured_line () {
		return $piece->last_captured_line;
	}
}

1;