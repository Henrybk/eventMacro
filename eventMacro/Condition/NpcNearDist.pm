package eventMacro::Condition::NpcNearDist;

use strict;
use Globals;
use Utils;

use base 'eventMacro::Condition::BaseActorNearDist';

sub _hooks {
	my ( $self ) = @_;
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('add_npc_list','npc_disappeared');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub _dynamic_hooks {
	my ( $self ) = @_;
	my $hooks = $self->SUPER::_dynamic_hooks;
	my @other_hooks = ('npc_moved','npcNameUpdate');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{actorList} = \$npcsList;
	$self->{actorType} = 'Actor::NPC';
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		
		if ($callback_name eq 'add_npc_list') {
			$self->{actor} = $args;
			$self->{hook_type} = 'add_list';

		} elsif ($callback_name eq 'npc_disappeared') {
			$self->{actor} = $args->{npc};
			$self->{hook_type} = 'disappeared';
		
		} elsif ($callback_name eq 'npcNameUpdate') {
			$self->{actor} = $args->{npc};
			$self->{hook_type} = 'NameUpdate';
			
		} elsif ($callback_name eq 'npc_moved') {
			$self->{actor} = $args;
			$self->{hook_type} = 'moved';
			
		} elsif ($callback_name eq 'packet/actor_movement_interrupted' || $callback_name eq 'packet/high_jump') {
			$self->{actor} = Actor::get($args->{ID});
			$self->{hook_type} = 'interrupted_or_jump';
		}
	}
	
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{fulfilled_actor}->{name};
	$new_variables->{".".$self->{name}."Last"."Pos"} = sprintf("%d %d %s", $self->{fulfilled_actor}->{pos_to}{x}, $self->{fulfilled_actor}->{pos_to}{y}, $field->baseName);
	$new_variables->{".".$self->{name}."Last"."BinId"} = $self->{fulfilled_actor}->{binID};
	$new_variables->{".".$self->{name}."Last"."Dist"} = distance($char->{pos_to}, $self->{fulfilled_actor}->{pos_to});
	
	return $new_variables;
}

1;
