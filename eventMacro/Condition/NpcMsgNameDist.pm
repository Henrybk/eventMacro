package eventMacro::Condition::NpcMsgNameDist;

use strict;
use Globals;
use Utils;

use eventMacro::Data;

use base 'eventMacro::Conditiontypes::BaseMsgNameDist';

sub _hooks {
	my ( $self ) = @_;
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('npc_talk');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{actorList} = \$npcsList;
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		$self->{message} = $args->{msg};
		$self->{source} = $args->{name};
	}
	
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

sub usable {
	1;
}

1;