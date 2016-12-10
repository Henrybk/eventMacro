package eventMacro::Condition::CharCurrentWeight;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );

sub _hooks {
	['packet/stat_info'];
}

sub _get_val {
    $char->{weight};
}

sub _get_ref_val {
    $char->{weight_max};
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		return $self->SUPER::validate_condition if $callback_name eq 'packet/stat_info' && $args && ( $args->{type} != 24 && $args->{type} != 25 );
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
	return $self->SUPER::validate_condition( $self->validator_check );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $char->{weight};
	$new_variables->{".".$self->{name}."Last"."Percent"} = ($char->{weight} / $char->{weight_max}) * 100;
	
	return $new_variables;
}

1;
