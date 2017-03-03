package eventMacro::Condition::PlayerNearCount;

use strict;
use Globals;
use Utils;
use base 'eventMacro::Condition::ActorNearCount';

use Globals;

sub _hooks {
	my ( $self ) = @_;
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('add_player_list','player_disappeared');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub _get_val {
	my ( $self ) = @_;
	return ($playersList->size + $self->{change});
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	if ($callback_type eq 'hook' && $callback_name eq 'player_disappeared') {
		$self->{change} = -1;
	} else {
		$self->{change} = 0;
	}
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

sub usable {
	1;
}

1;
