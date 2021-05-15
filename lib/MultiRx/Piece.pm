use v5.30;
use warnings FATAL => 'all', NONFATAL => qw/exec recursion internal malloc newline experimental deprecated portable/;
no warnings 'once';

use experimental qw/signatures refaliasing declared_refs/;

use Scalar::Util ();
use List::Util ();
use Carp ();

our $VERSION = "0.1";

use Object::Pad;

role MultiRx::Piece {
	# Fixed state
	has $source :reader;
	#method source { $source }
	has $parent :reader;
	#method parent { $parent }
	
	# Volatile state
	has $start :reader;
	#method start { $start }
	has $backref :mutator = ""; # Is not reset
	#method backref :lvalue { $backref }
	
	#requires count;

	method set_source ($newsrc) {
		Scalar::Util::blessed $newsrc or Carp::confess "Invalid non-object source";
		$newsrc->isa("MultiRx") or Carp::confess "Invalid source object of type";
		defined $source and Carp::confess "Invalid attempt to re-use bound piece";
		defined $parent and Carp::confess "Invalid attempt to set multiple sources";
		$source = $newsrc;
		return $self;
	}
	
	method set_parent ($newprnt) {
		MultiRx::is_piece $newprnt or Carp::confess "Invalid parent";
		defined $parent and Carp::confess "Invalid attempt to reparent piece";
		defined $source and Carp::confess "Invalid attempt to re-use root piece";
		$parent = $newprnt;
		$source = $newprnt->source;
		return $self;
	}
	
	method get_source () {
		defined $source and return $source;
		defined $parent and return $parent->get_source;
		Carp::confess "Use of unbound piece";
	}
	
	method end () {
		my $count = $self->count;
		return (defined $start && defined $count) ? ($start + $count) : undef;
	}
	
	#requires next;

	#requires _reset;
	method reset ($newstart = undef) {
		$start = $newstart;
		$self->_reset;
	}
	
	#requires last_captured_line;
	
	#requires _want_backref;
	method want_backref () {
		$backref = 1;
		for (my $p = $parent; defined $p && !($p->backref); $p = $p->parent) {
			$p->backref = 1;
		}
		$self->_want_backref;
	}
	
	
	#requires _save;
	method save {
		my %data = (
			start => $start,
			backref => $backref,
		);
		$self->_save(\%data);
		return \%data;
	}
	
	#requires _restore;
	method restore ($data) {
		my \%data = $data;
		($start, $backref) = @data{qw/start backref/};
		$self->_restore($data);
	}
}

1;