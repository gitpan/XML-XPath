# $Id: Attribute.pm,v 1.7 2000/09/25 13:33:15 matt Exp $

package XML::XPath::Node::Attribute;

use strict;
use vars qw/@ISA/;

@ISA = ('XML::XPath::Node');

package XML::XPath::Node::AttributeImpl;

use vars qw/@ISA/;
@ISA = ('XML::XPath::NodeImpl', 'XML::XPath::Node::Attribute');
use XML::XPath::Node ':node_keys';

sub new {
	my $class = shift;
	my ($key, $val, $prefix) = @_;
	
        my $pos = XML::XPath::Node->nextPos;
        
        my @vals;
        @vals[node_global_pos, node_prefix, node_key, node_value] =
                ($pos, $prefix, $key, $val);
	my $self = \@vals;
        
	bless $self, $class;
	
}

sub getNodeType { ATTRIBUTE_NODE }

sub isAttributeNode { 1; }

sub getName {
	my $self = shift;
	$self->[node_key];
}

sub getNodeValue {
	my $self = shift;
	$self->[node_value];
}

sub getData {
    shift->getNodeValue(@_);
}

sub setNodeValue {
    my $self = shift;
    $self->[node_value] = shift;
}

sub getPrefix {
	my $self = shift;
	$self->[node_prefix];
}

sub string_value {
	my $self = shift;
	return $self->[node_value];
}

sub toString {
	my $self = shift;
	my $string = ' ';
# 	if ($self->[node_prefix]) {
# 		$string .= $self->[node_prefix] . ':';
# 	}
	$string .= join('',
					$self->[node_key],
					'="',
					XML::XPath::Node::XMLescape($self->[node_value], '"&><'),
					'"');
	return $string;
}

sub getNamespace {
    my $self = shift;
    my ($prefix) = @_;
    $prefix ||= $self->getPrefix;
    if (my $parent = $self->getParentNode) {
        return $parent->getNamespace($prefix);
    }
}

1;
__END__

=head1 NAME

Attribute - a single attribute

=head1 API

=head2 new ( key, value, prefix )

Create a new attribute node.

=head2 getName

Returns the key for the attribute

=head2 getValue / getData

Returns the value

=head2 getPrefix

Returns the prefix

=head2 toString

Generates key="value", encoded correctly.

=cut
