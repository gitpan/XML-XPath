# $Id: Expr.pm,v 1.7 2000/02/10 09:58:59 matt Exp $

package XML::XPath::Expr;
use XML::XPath::Function;
use strict;

my $functioner; # Global functioner object. Don't ask.

sub new {
	my $class = shift;
	my ($pp) = @_;
	$functioner ||= XML::XPath::Function->new($pp);
	bless { pp => $pp, 
			predicates => [], 
		}, $class;
}

sub as_string {
	my $self = shift;
	my $string = "(" . $self->{lhs}->as_string;
	$string .= " " . $self->{op} . " " if defined $self->{op};
	$string .= $self->{rhs}->as_string if defined $self->{rhs};
	$string .= ")";
	foreach my $predicate (@{$self->{predicates}}) {
		$string .= "[" . $predicate->as_string . "]";
	}
	return $string;
}

sub set_lhs {
	my $self = shift;
	$self->{lhs} = $_[0];
}

sub set_op {
	my $self = shift;
	$self->{op} = $_[0];
}

sub set_rhs {
	my $self = shift;
	$self->{rhs} = $_[0];
}

sub push_predicate {
	my $self = shift;
	push @{$self->{predicates}}, $_[0];
}

sub get_lhs { $_[0]->{lhs}; }
sub get_rhs { $_[0]->{rhs}; }
sub get_op { $_[0]->{op}; }

sub evaluate {
	my $self = shift;
	my $node = shift;
	
	# If there's an op, result is result of that op.
	# If no op, just resolve Expr
	
	if ($self->{op}) {
		die ("No RHS of ", $self->as_string) unless $self->{rhs};
		return $self->op_eval($node);
	}
	else {
		return $self->{lhs}->evaluate($node);
	}
}

sub op_eval {
	my $self = shift;
	my $node = shift;
	
	my $op = $self->{op};
	
	for ($op) {
		/^or$/	&& do {
					return op_or($node, $self->{lhs}, $self->{rhs});
				};
		/^and$/	&& do {
					return op_and($node, $self->{lhs}, $self->{rhs});
				};
		/^=$/	&& do {
					return op_equals($node, $self->{lhs}, $self->{rhs});
				};
		/^!=$/	&& do {
					return op_nequals($node, $self->{lhs}, $self->{rhs});
				};
		/^<=$/	&& do {
					return op_le($node, $self->{lhs}, $self->{rhs});
				};
		/^>=$/	&& do {
					return op_ge($node, $self->{lhs}, $self->{rhs});
				};
		/^>$/	&& do {
					return op_gt($node, $self->{lhs}, $self->{rhs});
				};
		/^<$/	&& do {
					return op_lt($node, $self->{lhs}, $self->{rhs});
				};
		/^\+$/	&& do {
					return op_plus($node, $self->{lhs}, $self->{rhs});
				};
		/^-$/	&& do {
					return op_minus($node, $self->{lhs}, $self->{rhs});
				};
		/^div$/	&& do {
					return op_div($node, $self->{lhs}, $self->{rhs});
				};
		/^mod$/	&& do {
					return op_($node, $self->{lhs}, $self->{rhs});
				};
		/^\*$/	&& do {
					return op_mult($node, $self->{lhs}, $self->{rhs});
				};
		
		die "No such operator, or operator unimplemented in ", $self->as_string, "\n";
	}
}

# Operators

use XML::XPath::Boolean;

sub op_or {
	my ($node, $lhs, $rhs) = @_;
	if($lhs->evaluate($node)->to_boolean->value) {
		return XML::XPath::Boolean->True;
	}
	else {
		return $rhs->evaluate($node)->to_boolean;
	}
}

sub op_and {
	my ($node, $lhs, $rhs) = @_;
	if( ! $lhs->evaluate($node)->to_boolean->value ) {
		return XML::XPath::Boolean->False;
	}
	else {
		return $rhs->evaluate($node)->to_boolean;
	}
}

sub op_equals {
	my ($node, $lhs, $rhs) = @_;

	my $lh_results = $lhs->evaluate($node);
	my $rh_results = $rhs->evaluate($node);
	
	if ($lh_results->isa('XML::XPath::NodeSet') &&
			$rh_results->isa('XML::XPath::NodeSet')) {
		# True if and only if there is a node in the
		# first set and a node in the second set such
		# that the result of performing the comparison
		# on the string-values of the two nodes is true.
		foreach my $lhnode ($lh_results->get_nodelist) {
			foreach my $rhnode ($rh_results->get_nodelist) {
				if (XML::XPath::XMLParser::string_value($lhnode) eq
						XML::XPath::XMLParser::string_value($rhnode)) {
					return XML::XPath::Boolean->True;
				}
			}
		}
		return XML::XPath::Boolean->False;
	}
	elsif (($lh_results->isa('XML::XPath::NodeSet') ||
			$rh_results->isa('XML::XPath::NodeSet')) &&
			(!$lh_results->isa('XML::XPath::NodeSet') ||
			 !$rh_results->isa('XML::XPath::NodeSet'))) {
		# (that says: one is a nodeset, and one is not a nodeset)
		
		my ($nodeset, $other);
		if ($lh_results->isa('XML::XPath::NodeSet')) {
			$nodeset = $lh_results;
			$other = $rh_results;
		}
		else {
			$nodeset = $rh_results;
			$other = $lh_results;
		}
		
		# True if and only if there is a node in the
		# nodeset such that the result of performing
		# the comparison on <type>(string_value($node))
		# is true.
		if ($other->isa('XML::XPath::Number')) {
			foreach my $node ($nodeset->get_nodelist) {
				if ($functioner->_execute('number', $node, $node)->value
						== $other->value) {
					return XML::XPath::Boolean->True;
				}
			}
			return XML::XPath::Boolean->False;
		}
		elsif ($other->isa('XML::XPath::Literal')) {
			foreach my $node ($nodeset->get_nodelist) {
				if ($functioner->_execute('string', $node, $node)->value
						eq $other->value) {
					return XML::XPath::Boolean->True;
				}
			}
			return XML::XPath::Boolean->False;
		}
		elsif ($other->isa('XML::XPath::Boolean')) {
			if ($functioner->_execute('boolean', $node, $nodeset)->value
					== $other->value) {
				return XML::XPath::Boolean->True;
			}
			return XML::XPath::Boolean->False;
		}			
	}
	else { # Neither is a nodeset
		if ($lh_results->isa('XML::XPath::Boolean') ||
			$rh_results->isa('XML::XPath::Boolean')) {
			# if either is a boolean
			if ($functioner->_execute('boolean', $node, $lh_results)->value
					== $functioner->_execute('boolean', $node, $rh_results)->value) {
				return XML::XPath::Boolean->True;
			}
			return XML::XPath::Boolean->False;
		}
		elsif ($lh_results->isa('XML::XPath::Number') ||
				$rh_results->isa('XML::XPath::Number')) {
			# if either is a number
			if ($functioner->_execute('number', $node, $lh_results)->value
					== $functioner->_execute('number', $node, $rh_results)->value) {
				return XML::XPath::Boolean->True;
			}
			return XML::XPath::Boolean->False;
		}
		else {
			if ($functioner->_execute('string', $node, $lh_results)->value
					eq $functioner->_execute('string', $node, $rh_results)->value) {
				return XML::XPath::Boolean->True;
			}
			return XML::XPath::Boolean->False;
		}
	}
}

sub op_nequals {
	my ($node, $lhs, $rhs) = @_;
	if (op_equals($node, $lhs, $rhs)->value) {
		return XML::XPath::Boolean->False;
	}
	return XML::XPath::Boolean->True;
}

sub op_le {
	my ($node, $lhs, $rhs) = @_;
	
}

sub op_ge {
	my ($node, $lhs, $rhs) = @_;
	
}

sub op_gt {
	my ($node, $lhs, $rhs) = @_;
	
}

sub op_lt {
	my ($node, $lhs, $rhs) = @_;
	
}

sub op_plus {
	my ($node, $lhs, $rhs) = @_;
	
}

sub op_minus {
	my ($node, $lhs, $rhs) = @_;
	
}

sub op_div {
	my ($node, $lhs, $rhs) = @_;
	
}

sub op_mod {
	my ($node, $lhs, $rhs) = @_;
	
}

sub op_mult {
	my ($node, $lhs, $rhs) = @_;
	
}

1;
