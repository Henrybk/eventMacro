package eventMacro::Condition::ActorNearCount;

use strict;
use Globals;
use Utils;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals;

#'packet/map_property3' has to exchanged
sub _hooks {
	['packet_mapChange','packet/map_property3'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{is_on_stand_by} = 1;
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub _get_val {
    0;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		if ($callback_name eq 'packet_mapChange') {
			$self->{is_on_stand_by} = 1;
		} elsif ($callback_name eq 'packet/map_property3') {
			$self->{is_on_stand_by} = 0;
		}
	}
	
	return $self->SUPER::validate_condition(0) if ($self->{is_on_stand_by} == 1);
	return $self->SUPER::validate_condition( $self->validator_check );
}

sub usable {
	0;
}

1;
