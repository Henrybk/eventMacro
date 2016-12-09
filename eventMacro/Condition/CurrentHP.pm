package eventMacro::Condition::CurrentHP;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );

sub _hooks {
	[ 'packet/sendMapLoaded', 'packet/hp_sp_changed', 'packet/stat_info' ];
}

sub _get_val {
	$char->{hp};
}

sub _get_ref_val {
	$char->{hp_max};
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		$self->SUPER::validate_condition if $callback_name eq 'packet/stat_info'     && $args && $args->{type} != 5;
		$self->SUPER::validate_condition if $callback_name eq 'packet/hp_sp_changed' && $args && $args->{type} != 5;
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
	$self->SUPER::validate_condition(  $self->validator_check );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $char->{hp};
	$new_variables->{".".$self->{name}."Last"."Percent"} = ($char->{hp} / $char->{hp_max}) * 100;
	
	return $new_variables;
}

1;
