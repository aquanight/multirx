use v5.30;
use warnings FATAL => 'all', NONFATAL => qw/exec recursion internal malloc newline experimental deprecated portable/;
no warnings 'once';

use experimental qw/signatures refaliasing declared_refs/;

use Scalar::Util ();
use List::Util ();
use Carp ();

our $VERSION = "0.1";

use Object::Pad;

class MultiRx::LazyRepeatPiece extends MultiRx::RepeatPiece {

	# In lazy-repeat, we try to match as few iterations as we can.
	
	method _step_success () {
		# Have we reached our *minimum* match count?
		if ($self->_itcount + 1 >= $self->min) {
			# Then return successfully now.
			$self->done = 1;
			return 1;
		}
		$self->_pushit;
		unshift @_, $self;
		goto &{$self->can("next")};
	}
	
	method _step_failure () {
		# No (more) matches possible at this iteration, we need to try
		# something else. Because we are now growing upward, it means we need
		# to immediately try to step the next lower iteration.
		unless ($self->_popit) {
			# We have run out of possible matches at the first iteration.
			# That means we have now exhausted all possible matches.
			$self->done = 1;
			return "";
		}
		unshift @_, $self;
		goto &{$self->can("_step")};
	}
	
	method _next_backtrack () {
		# We're being backtracked.
		# Note: mode = atomic is not handled here: that's done by wrapping us in an AtomicPiece which will never call back in once
		# lock in a match until a ->reset.
		# Does the last piece have any alternative options?
		$self->done = "";
		unless (defined $self->piece->start) {
			# This situation happens if we returned a match at
			# repetition count 0. Unlike greedy match, this is the *first*
			# thing we try if $min is 0, so prep the piece for the first
			# iteration and goooooo.
			$self->piece->reset($self->start);
			unshift @_, $self;
			goto &_step;
		}
		# Do we possibly have room for another iteration?
		if (!defined $self->max || $self->_itcount + 1 < $self->max) {
			# Then push our last iteration and start a new one.
			$self->_pushit;
			unshift @_, $self;
			goto &_step;
		}
		# Otherwise we need to try an alternative match for our most recent
		# iteration.
		unshift @_, $self;
		goto &{$self->can("_step")};
	}
	
	method _first () {
		if ($self->min < 1) {
			# We have a minimum of 0, so we can return success *immediately*.
			$self->done = 1;
			return 1;
		}
		# Otherwise, setup for the first iteration and gooooo.
		$self->piece->reset($self->start);
		unshift @_, $self;
		goto &{$self->can("_step")};
	}

}

1;