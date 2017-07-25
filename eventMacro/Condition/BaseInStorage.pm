package eventMacro::Condition::BaseInStorage;

use strict;

use base 'eventMacro::Condition::BaseInventory';

use Globals qw( $char );

sub _hooks {
	['storage_first_session_openning','packet/storage_item_added','storage_item_removed'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {

		if ($callback_name eq 'storage_first_session_openning') {
			$self->{is_on_stand_by} = 0;
		}
		
	} elsif ($callback_type eq 'recheck') {
		$self->{is_on_stand_by} = $char->storage->wasOpenedThisSession ? 0 : 1;
	}
	
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

1;
