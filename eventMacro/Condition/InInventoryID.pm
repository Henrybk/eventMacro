package eventMacro::Condition::InInventoryID;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );
use eventMacro::Data;
use eventMacro::Utilities qw(find_variable getInventoryAmountbyID);

sub _hooks {
	['packet_mapChange','inventory_ready','item_gathered','inventory_item_removed'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{wanted_ID} = undef;
	
	if ($condition_code =~ /^(\d+)\s+(\S.*)$/) {
		$self->{wanted_ID} = $1;
		$condition_code = $2;
	} else {
		$self->{error} = "Item name must be inside quotation marks and a numeric comparison must be given";
		return 0;
	}
	
	$self->{is_on_stand_by} = 1;
	
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub _get_val {
	my ( $self ) = @_;
	getInventoryAmountbyID($self->{wanted_ID});
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {

		if ($callback_name eq 'packet_mapChange') {
			$self->{fulfilled_binID} = undef;
			$self->{is_on_stand_by} = 1;
			
		} elsif ($callback_name eq 'inventory_ready') {
			$self->{is_on_stand_by} = 0;
			
		}
		
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
		
	} elsif ($callback_type eq 'recheck') {
		$self->{is_on_stand_by} = 0;
	}
	
	if ($self->{is_on_stand_by} == 1) {
		return $self->SUPER::validate_condition(0);
	} else {
		return $self->SUPER::validate_condition( $self->validator_check );
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{wanted_ID};
	$new_variables->{".".$self->{name}."LastAmount"} = getInventoryAmountbyID($self->{wanted_ID});
	
	return $new_variables;
}

1;
