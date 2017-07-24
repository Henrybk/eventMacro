package eventMacro::Condition::InInventory;

use strict;

use base 'eventMacro::Condition::BaseInInventory';

use Globals qw( $char );

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{wanted} = undef;
	
	if ($condition_code =~ /"(.+)"\s+(\S.*)/) {
		$self->{wanted} = $1;
		$condition_code = $2;
	} else {
		$self->{error} = "Item name must be inside quotation marks and a numeric comparison must be given";
		return 0;
	}
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub _get_val {
	my ( $self ) = @_;
	$char->inventory->sumByName($self->{wanted});
}

sub usable {
	1;
}

1;
