use v5.30;
use warnings FATAL => 'all', NONFATAL => qw/exec recursion internal malloc newline experimental deprecated portable/;
no warnings 'once';

use experimental qw/signatures refaliasing declared_refs/;

use Scalar::Util ();
use List::Util ();
use Carp ();

our $VERSION = "0.1";

use Object::Pad;

class MultiRx::SequencePiece implements MultiRx::Piece {
	has $count = undef;
	has @seq;
	has @seqstate;
	has $next = 0;
	has %nocount;
	
	method count { $count//0 }
	
	# State:
	# Initial: next = 0
	# Incomplete sequence: next = index of piece we need to resume at.
	# Ready to complete sequence: next = @seq
	# Completed sequence: next = @seq + 1
	
	BUILD {
		grep {!MultiRx::is_piece($_)} @_ and Carp::confess "Invalid piece object";
		@seq = @_;
		$_->set_parent($self) foreach @seq;
	}
	
	method _reset {
		$_->reset foreach @seq;
		$count = undef;
		$next = 0;
		undef %nocount;
	}
	
	method _save ($data) {
		$data->@{qw/count next seq/} = ($count, $next, [ @seqstate ]);
	}
	
	method _restore ($data) {
		($count, $next, @seqstate) = $data->{count}, $data->{next}, $data->{seq}->@* ;
	}
	
	method _want_backref () {
		for my $p (@seq) {
			$p->want_backref;
		}
	}
	
	method _set_next ($index) {
		$next = $index;
		$seq[$index]->reset if $next <= $#seq;
		#$self->backref and $seq[$index]->_want_backref;
		if (defined $seqstate[$index]) {
			$seq[$index]->restore($seqstate[$index]);
			$seqstate[$index] = undef;
		}
	}
	
	method _step () {
		$count -= $seq[$next]->count;
		my $r = $seq[$next]->next;
		if ($r//1) {
			$count += $seq[$next]->count;
			if ($r) {
				$seqstate[$next] = $seq[$next]->save;
				$self->_set_next($next + 1);
				unshift @_, $self;
				goto &next;
			}
			return undef;
		}
		else {
			# No (more) matches possible at this step. Need to step back and try another.
			$seq[$next]->reset;
			if ($next == 0) {
				# No more backsteps left: match failure.
				return "";
			}
			$self->_set_next($next - 1);
			unshift @_, $self;
			goto &_step;
		}
	}
	
	method next () {
		unless (defined $count) {
			@seq > 0 or return 1;
			$seq[0]->reset($self->start);
			return $self->_step;
		}
		if ($next > scalar @seq) {
			$self->_set_next($#seq);
		}
		if ($next == scalar @seq) {
			++$next;
			if (!$self->backref && $nocount{$count}) {
				unshift @_, $self;
				goto &next;
			}
			$nocount{$count} = 1;
			return 1;
		}
		unless (defined $seq[$next]->start) {
			$seq[$next]->reset($self->end);
		}
		unshift @_, $self;
		goto &_step;
	}
	
	method last_captured_line () {
		$#seq >= 0 or return undef;
		return $seq[-1]->last_captured_line;
	}
}

1;