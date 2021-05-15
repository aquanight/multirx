use v5.30;
use warnings FATAL => 'all', NONFATAL => qw/exec recursion internal malloc newline experimental deprecated portable/;
no warnings 'once';

use experimental qw/signatures refaliasing declared_refs/;

use Scalar::Util ();
use List::Util ();
use Carp ();

our $VERSION = "0.1";

use Object::Pad;

class MultiRx::VerbPiece implements MultiRx::Piece {
	has $verb;
	has @params;
	
	has $done = "";
	
	# Description of verbs:
	# *MARK:NAME - If it's on the success path, it'll set $rx->MARK ($rx is the MultiRx
	#              object) to NAME. If the regex fails, the last executed MARK is put in
	#              $REGERROR.
	
	BUILD {
		($verb, @params) = @_;
		defined $verb or do {
			Carp::carp "Use of uninitialized value in verb";
			$verb = "MARK";
		}
		length $verb or $verb = "MARK";
		for (@params) {
			unless (defined $_) {
				Carp::carp "Use of uninitialized value in verb argument";
				$_ = "";
			}
		}
	}
	
	method _reset { $done = ""; }
	
	method _save { }
	
	method _restore { }
	
	method last_captured_line { }
	
	method _want_backref () { }
	
	# Called from MultiRx if we throw the verb to signal a regex bailout. We basically
	# take control from the matching routine ($rx->next) and can decide what to do.
	# This is not called when pieces respond to specific verbs, such as AnyPiece handling
	# the *THEN verb.
	method _verb_bt ($break) {
		
	}
	
	method next () {
		
	}
}

1;