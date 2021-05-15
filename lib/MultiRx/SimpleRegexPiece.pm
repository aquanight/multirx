use v5.30;
use warnings FATAL => 'all', NONFATAL => qw/exec recursion internal malloc newline experimental deprecated portable/;
no warnings 'once';

use experimental qw/signatures refaliasing declared_refs/;

use Scalar::Util ();
use List::Util ();
use Carp ();

our $VERSION = "0.1";

use Object::Pad;

class MultiRx::SimpleRegexPiece implements MultiRx::Piece {
	has $regex;
	has $done = "";
	has $plus;
	has $minus;
	has %seen;
	
	BUILD {
		my $rx = $_[0];
		Scalar::Util::blessed $rx && $rx->isa("Regexp") or Carp::croak "Invalid regex object";
		$regex = $rx;
	}
	
	method _reset {
		$done = "";
		$plus = undef;
		$minus = undef;
		undef %seen;
	}
	
	method _save ($data) {
		$data->@{qw/done + - seen/} = (
			$done,
			$plus,
			$minus,
			[keys %seen],
		)
	}
	
	method _restore ($data) {
		($done, $plus, $minus, %seen) = $data->@{qw/done + -/}, map { $_ => 1 } $data->{seen}->@*;
	}
	
	method seen {
		no warnings 'uninitialized';
		my $k = sprintf "[%s][%s]", join(":",@-), join (":",@+);
		if ($seen{$k}) {
			return "(?!)";
		}
		else {
			$seen{$k} = 1;
			return "";
		}
	}
	
	method count { $done ? 1 : 0 }
	
	method next () {
		if ($done) {
			$plus = undef;
			$minus = undef;
			return "" unless $self->backref; # If backref'd, we need to iterate other possible matches.
			$done = 0;
		}
		unless ($self->get_source->input_available($self->start)) {
			return undef;
		}
		$done = 1;
		my $line = $self->get_source->get_input($self->start);
		return "" unless defined $line;
		if (defined $line && $line =~ m/$regex(??{ $self->seen; })/) {
			$plus = [ @+ ];
			$minus = [ @- ];
			return 1;
		}
		else {
			$plus = undef;
			$minus = undef;
			return "";
		}
	}
	
	method _want_backref { }
	
	method last_captured_line { $self }
}

1;