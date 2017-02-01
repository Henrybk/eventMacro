package DynamicAutoVarsTest;

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin";

use Test::More;
use eventMacro::Core;
use eventMacro::Data;
use eventMacro::Runner;
use eventMacro::FileParser;
use eventMacro::Utilities qw(find_variable);

sub start {
	my $parsed = parseMacroFile( "$RealBin/LoadConditionsTest.txt", 0 );
	
	ok ($parsed);
	
	$eventMacro = eventMacro::Core->new( "$RealBin/LoadConditionsTest.txt" );
	
	ok (defined $eventMacro);
	use Data::Dumper;
	
	Log::warning "[dynamictest] start\n";
	
	Log::warning "[test] Dumper dynamic comp '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	
	Log::warning "[dynamictest] var NestedScalar1 change to 2\n";
	$eventMacro->set_scalar_var('NestedScalar1', 2);
	
	Log::warning "[test] Dumper dynamic comp '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	
	Log::warning "[dynamictest] var NestedScalar1 change to 27\n";
	$eventMacro->set_scalar_var('NestedScalar1', 27);
	
	Log::warning "[test] Dumper dynamic comp '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	
	Log::warning "[dynamictest] var NestedScalar1 change to undef\n";
	$eventMacro->set_scalar_var('NestedScalar1', 'undef');
	
	Log::warning "[test] Dumper dynamic comp '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	
	Log::warning "[dynamictest] var NestedScalar1 change to 5\n";
	$eventMacro->set_scalar_var('NestedScalar1', 5);
	
	Log::warning "[test] Dumper dynamic comp '".Dumper($eventMacro->{Dynamic_Variable_Complements})."'\n";
	Log::warning "[test] Dumper dynamic sub '".Dumper($eventMacro->{Dynamic_Variable_Sub_Callbacks})."'\n";
	
}

1;