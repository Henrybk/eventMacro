package eventMacro::Condition::BaseInCart;

use strict;

use base 'eventMacro::Condition::BaseInventory';

use Globals qw( $char );


sub _hooks {
	['packet_mapChange','cart_ready','packet/cart_item_added','cart_item_removed','packet/cart_off'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {

		if ($callback_name eq 'packet_mapChange') {
			$self->{is_on_stand_by} = 1;
			
		} elsif ($callback_name eq 'cart_ready') {
			$self->{is_on_stand_by} = 0;
			
		} elsif ($callback_name eq 'packet/cart_off') {
			$self->{is_on_stand_by} = 1;
		}
		
	} elsif ($callback_type eq 'recheck') {
		$self->{is_on_stand_by} = $char->cart->isReady ? 0 : 1;
	}
	
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

1;
