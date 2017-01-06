package eventMacro::Condition::JobID;

use strict;

use base 'eventMacro::Condition';

use Globals qw( $char );
use eventMacro::Data;
use eventMacro::Utilities qw(find_variable);

sub _hooks {
	['in_game','packet/player_equipment'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{wanted_id} = undef;
	
	if (my $var = find_variable($condition_code)) {
		if ($var =~ /^\./) {
			$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
			return 0;
		} else {
			push ( @{ $self->{variables} }, $var );
		}
	} elsif ($condition_code =~ /^(\d+)$/) {
		$self->{wanted_id} = $1;
	} else {
		$self->{error} = "Job ID '".$condition_code."' must be a ID number or a variable";
		return 0;
	}
	
	return 1;
}

sub update_vars {
	my ( $self, $var_name, $var_value ) = @_;
	if ($var_value =~ /^\d+$/) {
		$self->{wanted_id} = $var_value;
	} else {
		$self->{wanted_id} = undef;
	}
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		return $self->SUPER::validate_condition if ($callback_name eq 'packet/player_equipment' && (!$args || !exists $args->{type} || $args->{type} != 0));
	} elsif ($callback_type eq 'variable') {
		$self->update_vars($callback_name, $args);
	}
	
	if (!defined $self->{wanted_id}) {
		return $self->SUPER::validate_condition(0);
	} else {
		return $self->SUPER::validate_condition( ($self->{wanted_id} == $char->{jobID} ? 1 : 0) );
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $char->{jobID};
	
	return $new_variables;
}

1;
