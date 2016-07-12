# $Id: Script.pm r6782 2009-07-24 16:36:00Z ezza $
package eventMacro::Runner;

use strict;

require Exporter;
our @ISA = qw(Exporter);

use Time::HiRes qw( &time );
use Utils;
use Globals;
use AI;
use Log qw(message error warning debug);

use eventMacro::Data;
use eventMacro::Core;
use eventMacro::Parser qw(parseCmd);
use eventMacro::FileParser qw(isNewCommandBlock);
use eventMacro::Utilities qw(cmpr);
use eventMacro::Automacro;

our ($rev) = q$Revision: 6782 $ =~ /(\d+)/;

our %macro;
our @EXPORT_OK = qw( %macro );

# constructor
sub new {
	my ($class, $name, $repeat, $lastname, $lastline, $interruptible) = @_;

	return undef unless ($eventMacro->{Macro_List}->getByName($name));
	
	$repeat = 0 unless ($repeat && $repeat =~ /^\d+$/);
	$macro{$name} = $eventMacro->{Macro_List}->getByName($name)->get_lines();
	my $self = {
			Name => $name,
			Paused => 0,
			lastname => undef,
			registered => 0,
			submacro => 0,
			macro_delay => $timeout{eventMacro_delay}{timeout},
			timeout => 0,
			mainline_delay => undef,
			subline_delay => undef,
			result => undef,
			time => time,
			finished => 0,
			overrideAI => 0,
			line => 0,
			lastline => undef,
			label => {scanLabels($macro{$name})},
			repeat => $repeat,
			subcall => undef,
			error => undef,
			orphan => $config{eventMacro_orphans},
			interruptible => 1,
			macro_block => 0

	};
	if (defined $lastname && defined $lastline) {
		$self->{lastname} = $lastname;
		$self->{lastline} = $lastline
	}
	if (defined $interruptible) {$self->{interruptible} = $interruptible}
		
	bless ($self, $class);
	return $self
}

sub pause {
	my ($self) = @_;
	$self->{Paused} = 1;
}

sub unpause {
	my ($self) = @_;
	$self->{Paused} = 0;
}

sub is_paused {
	my ($self) = @_;
	return $self->{Paused};
}

sub get_name {
	my ($self) = @_;
	return $self->{Name};
}

# destructor
sub DESTROY {
	AI::clear('eventMacro') if (AI::inQueue('eventMacro') && !$_[0]->{submacro})
}

# declares current macro to be a submacro
sub regSubmacro {
	$_[0]->{submacro} = 1
}

# registers to AI queue
sub register {
	AI::queue('eventMacro') unless $_[0]->{overrideAI};
	$_[0]->{registered} = 1
}

# checks register status
sub registered {
	return $_[0]->{registered}
}

# sets or gets method for orphaned macros
sub orphan {
	if (defined $_[1]) {$_[0]->{orphan} = $_[1]}
	return $_[0]->{orphan}
}

# sets macro_delay timeout for this macro
sub setMacro_delay {
	$_[0]->{macro_delay} = $_[1]
}

# sets or gets timeout for next command
sub timeout {
	if (defined $_[1]) {$_[0]->{timeout} = $_[1]}
	return { time => $_[0]->{time}, timeout => $_[0]->{timeout} };
}

# sets or gets override AI value
sub overrideAI {
	if (defined $_[1]) {$_[0]->{overrideAI} = $_[1]}
	return $_[0]->{overrideAI}
}

# sets or get interruptible flag
sub interruptible {
	if (defined $_[1]) {$_[0]->{interruptible} = $_[1]}
	return $_[0]->{interruptible}
}

# sets or gets macro block flag
sub macro_block {
	my $script = $_[0];
	do {
		if (defined $_[1]) {
			$script->{macro_block} = $_[1];
		} else {
			return $script->{macro_block} if $script->{macro_block};
		}
	} while $script = $script->{subcall};
	
	return $_[1];
}
=pod
sub macro_block {
	if (defined $_[1]) {$_[0]->{macro_block} = $_[1]}
	return $_[0]->{macro_block}
}
=cut

# returns whether or not the macro finished
sub finished {
	return $_[0]->{finished}
}

# returns the name of the current macro
sub name {
	return $_[0]->{Name}
}

# returns the current line number
sub line {
	return $_[0]->{line}
}

# returns the error line
sub error {
	return $_[0]->{error}
}

# re-sets the timer
sub ok {
	$_[0]->{time} = time
}

# scans the script for labels
sub scanLabels {
	my $script = $_[0];
	my %labels;
	for (my $line = 0; $line < @{$script}; $line++) {
		if (${$script}[$line] =~ /^:/) {
			my ($label) = ${$script}[$line] =~ /^:(.*)/;
			$labels{$label} = $line
		}
		if (${$script}[$line] =~ /^while\s+/) {
			my ($label) = ${$script}[$line] =~ /\s+as\s+(.*)/;
			$labels{$label} = $line
		}
		if (${$script}[$line] =~ /^end\s+/) {
			my ($label) = ${$script}[$line] =~ /^end\s+(.*)/;
			$labels{"end ".$label} = $line
		}
	}
	return %labels
}

# processes next line
sub next {
	my $self = $_[0];
	
	if (defined $self->{subcall}) {
		my $command = $self->{subcall}->next;
		if (defined $command) {
			my $tmptime = $self->{subcall}->timeout;
			$self->{timeout} = $tmptime->{timeout};
			$self->{time} = $tmptime->{time};
			if ($self->{subcall}->finished) {
				if ($self->{subcall}->{repeat} == 0) {$self->{finished} = 1}
				undef $self->{subcall};
				# $self->{line}++
			}
			return $command
		}
		$self->{error} = $self->{subcall}->{error};
		return
	}
	
	if (defined $self->{mainline_delay} && defined $self->{subline_delay}) {$self->{line} = $self->{mainline_delay}}
	my $line = ${$macro{$self->{Name}}}[$self->{line}];
	if (!defined $line) {
		if (defined $self->{lastname} && defined $self->{lastline}) {
			if ($self->{repeat} > 1) {$self->{repeat}--; $self->{line} = 0}
			else {
				$self->{line} = $self->{lastline} + 1;
				$self->{Name} = $self->{lastname};
				($self->{lastline}, $self->{lastname}) = undef;
				$self->{finished} = 1
			}
			$line = ${$macro{$self->{Name}}}[$self->{line}]
		}
		else {
			if ($self->{repeat} > 1) {$self->{repeat}--; $self->{line} = 0}
			else {$self->{finished} = 1}
			return ""
		}
	}
	
	# TODO: separate line advancing and timeout setting
	
	my $errtpl = "error in ".$self->{line};

	# "If" postfix control
	if ($line =~ /.+\s+if\s*\(.*\)$/) {
		my ($text) = $line =~ /.+\s+if\s*\(\s*(.*)\s*\)$/;
		$text = parseCmd($text, $self);
		if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
		my $savetxt = particle($text, $self, $errtpl);
		if (multi($savetxt, $self, $errtpl)) {
			$line =~ s/\s+if\s*\(.*\)$//;
		} else {
			$self->{line}++;
			$self->{timeout} = 0;
			return "";
		}
	}
	
	##########################################
	# jump to label: goto label
	if ($line =~ /^goto\s/) {
		my ($tmp) = $line =~ /^goto\s+([a-zA-Z][a-zA-Z\d]*)/;
		if (exists $self->{label}->{$tmp}) {$self->{line} = $self->{label}->{$tmp}}
		else {$self->{error} = "$errtpl: cannot find label $tmp"}
		$self->{timeout} = 0
	##########################################
	# declare block ending: end label
	} elsif ($line =~ /^end\s/) {
		my ($tmp) = $line =~ /^end\s+(.*)/;
		if (exists $self->{label}->{$tmp}) {$self->{line} = $self->{label}->{$tmp}}
		else {$self->{error} = "$errtpl: cannot find block start for $tmp"}
		$self->{timeout} = 0
	##########################################
	# macro block: begin
	} elsif ($line eq '[') {
		$self->{macro_block} = 1;
		$self->{line}++
	##########################################
	# macro block: end
	} elsif ($line eq ']') {
		$self->{macro_block} = 0;
		$self->{timeout} = 0;
		$self->{line}++
	##########################################
	# if statement: if (foo = bar) goto label?
	# Unlimited If Statement by: ezza @ http://forums.openkore.com/
	} elsif ($line =~ /^if\s/) {
		my ($text, $then) = $line =~ /^if\s+\(\s*(.*)\s*\)\s+(goto\s+.*|call\s+.*|stop|{|)\s*/;

		# The main trick is parse all the @special keyword and vars 1st,
		$text = parseCmd($text, $self);
		if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
		my $savetxt = particle($text, $self, $errtpl);
		if (multi($savetxt, $self, $errtpl)) {
			newThen($then, $self, $errtpl);
			if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
		} elsif ($then eq "{") { # If the condition is false because "if" this is not using the command block
			my $countBlockIf = 1;
			while ($countBlockIf) {
				$self->{line}++;
				my $searchEnd = ${$macro{$self->{Name}}}[$self->{line}];
				
				if ($searchEnd =~ /^if.*{$/) {
					$countBlockIf++;
				} elsif (($searchEnd eq '}') || ($searchEnd =~ /^}\s*else\s*{$/ && $countBlockIf == 1)) {
					$countBlockIf--;
				} elsif ($searchEnd =~ /^}\s*elsif\s+\(\s*(.*)\s*\).*{$/ && $countBlockIf == 1) {
					# If the condition of 'elsif' is true, the commands of your block will be executed,
					#  if false, will not run.
					$text = parseCmd($1, $self);
					if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
					$savetxt = particle($text, $self, $errtpl);
					if (multi($savetxt, $self, $errtpl)) {
						$countBlockIf--;
					}
				}
			}
		}
		$self->{line}++;
		$self->{timeout} = 0

	##########################################
	# If arriving at a line 'else', 'elsif' or 'case', it should be skipped -
	#  it will never be activated if coming from a false 'if' or a previous 'case' has not been called
	} elsif ($line =~ /^}\s*else\s*{/ || $line =~ /^}\s*elsif.*{$/ || $line =~ /^case/ || $line =~ /^else/) {
		my $countCommandBlock = 1;
		while ($countCommandBlock) {
			$self->{line}++;
			my $searchEnd = ${$macro{$self->{Name}}}[$self->{line}];
			
			if (isNewCommandBlock($searchEnd)) {
				$countCommandBlock++;
			} elsif ($searchEnd eq '}') {
				$countCommandBlock--;
			}
		}

		$self->{timeout} = 0

	##########################################
	# switch statement:
	} elsif ($line =~ /^switch.*{$/) {
		my ($firstPartCondition) = $line =~ /^switch\s*\(\s*(.*)\s*\)\s*{$/;

		my $countBlocks = 1;
		while ($countBlocks) {
			$self->{line}++;
			my $searchNextCase = ${$macro{$self->{Name}}}[$self->{line}];
			
			if ($searchNextCase =~ /^else/) {
				my ($then) = $searchNextCase =~ /^else\s*(.*)/;
				newThen($then, $self, $errtpl);
				if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
				last;
			}
			
			my ($secondPartCondition, $then) = $searchNextCase =~ /^case\s*\(\s*(.*)\s*\)\s*(.*)/;
			next if (!$secondPartCondition);
			
			my $completCondition = $firstPartCondition . ' ' . $secondPartCondition;
			my $text = parseCmd($completCondition, $self);
			if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
			my $savetxt = particle($text, $self, $errtpl);
			if (multi($savetxt, $self, $errtpl)) {
				newThen($then, $self, $errtpl);
				if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
				last;
			} elsif ($searchNextCase =~ /^case.*{$/) {
				my $countCommandBlock = 1;
				while ($countCommandBlock) {
					$self->{line}++;
					my $searchEnd = ${$macro{$self->{Name}}}[$self->{line}];
					
					if (isNewCommandBlock($searchEnd)) {
						$countCommandBlock++;
					} elsif ($searchEnd eq '}') {
						$countCommandBlock--;
					}
				}
			}
		}
		
		$self->{line}++;
		$self->{timeout} = 0
	
	##########################################
	# end block of "if" or "switch"
	} elsif ($line eq '}') {
		$self->{line}++;
		$self->{timeout} = 0

	##########################################
	# while statement: while (foo <= bar) as label
	} elsif ($line =~ /^while\s/) {
		my ($text, $label) = $line =~ /^while\s+\(\s*(.*)\s*\)\s+as\s+(.*)/;
		my $text = parseCmd($text, $self);
		if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
		my $savetxt = particle($text, $self, $errtpl);
		if (!multi($savetxt, $self, $errtpl)) {
			$self->{line} = $self->{label}->{"end ".$label};
		}
		$self->{line}++;
		$self->{timeout} = 0
	##########################################
	# set variable: $variable = value
	} elsif ($line =~ /^\$[a-z]/i) {
		my ($var, $val);
		if ($line =~ /;/) {run_sublines($line, $self); if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
		} else {
			if (($var, $val) = $line =~ /^\$([a-z][a-z\d]*?)\s+=\s+(.*)/i) {
				my $pval = parseCmd($val, $self);
				if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
				if (defined $pval) {
					if ($pval =~ /^\s*(?:undef|unset)\s*$/i && $eventMacro->exists_var($var)) {$eventMacro->set_var($var, 'undef')}
					else {$eventMacro->set_var($var, $pval);}
				}
				else {$self->{error} = "$errtpl: $val failed"}
			} elsif (($var, $val) = $line =~ /^\$([a-z][a-z\d]*?)([+-]{2})$/i) {
				if ($val eq '++') {
					if ($eventMacro->is_var_defined($var)) {
						$eventMacro->set_var($var, ($eventMacro->get_var($var)+1));
					} else {
						$eventMacro->set_var($var, 1);
					}
				} else {
					if ($eventMacro->is_var_defined($var)) {
						$eventMacro->set_var($var, ($eventMacro->get_var($var)-1));
					} else {
						$eventMacro->set_var($var, -1);
					}
				}
			} else {$self->{error} = "$errtpl: unrecognized assignment"}
		$self->{line}++;
		$self->{timeout} = 0 unless defined $self->{mainline_delay} && defined $self->{subline_delay};
		return $self->{result} if $self->{result}
		}
	##########################################
	# label definition: :label
	} elsif ($line =~ /^:/) {
		$self->{line}++;
		$self->{timeout} = 0
	##########################################
	# returns command: do whatever
	} elsif ($line =~ /^do\s/) {
		if ($line =~ /;/ && $line =~ /^do eval/ eq "") {
			run_sublines($line, $self);
			if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
			unless (defined $self->{mainline_delay} && defined $self->{subline_delay}) {$self->{timeout} = $self->{macro_delay}; $self->{line}++}
			if ($self->{result}) {return $self->{result}}
		}
		else {
			my ($tmp) = $line =~ /^do\s+(.*)/;
			if ($tmp =~ /^macro\s+/) {
				my ($arg) = $tmp =~ /^macro\s+(.*)/;
				if ($arg =~ /^reset/) {$self->{error} = "$errtpl: use 'release' instead of 'macro reset'"}
				elsif ($arg eq 'pause' || $arg eq 'resume') {$self->{error} = "$errtpl: do not use 'macro pause' or 'macro resume' within a macro"}
				elsif ($arg =~ /^set\s/) {$self->{error} = "$errtpl: do not use 'macro set'. Use \$foo = bar"}
				elsif ($arg eq 'stop') {$self->{error} = "$errtpl: use 'stop' instead"}
				elsif ($arg !~ /^(?:list|status)$/) {$self->{error} = "$errtpl: use 'call $arg' instead of 'macro $arg'"}
			}
			elsif ($tmp =~ /^ai\s+clear$/) {$self->{error} = "$errtpl: do not mess around with ai in macros"}
			my $result = parseCmd($tmp, $self);
			if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
			unless (defined $result) {$self->{error} = "$errtpl: command $tmp failed";return}
			$self->{timeout} = $self->{macro_delay};
			$self->{line}++;
			return $result
		}
	##########################################
	# log command
	} elsif ($line =~ /^log\s+/) {
		if ($line =~ /;/) {run_sublines($line, $self); if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}}
		else {
			my ($tmp) = $line =~ /^log\s+(.*)/;
			my $result = parseCmd($tmp, $self);
			if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
			unless (defined $result) {$self->{error} = "$errtpl: $tmp failed"}
			else {message "[eventmacro log] $result\n", "eventMacro";}
		}
		$self->{line}++;
		$self->{timeout} = $self->{macro_delay} unless defined $self->{mainline_delay} && defined $self->{subline_delay};
		return $self->{result} if $self->{result}
	##########################################
	# pause command
	} elsif ($line =~ /^pause/) {
		if ($line =~ /;/) {
			run_sublines($line, $self);
			if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
			$self->{timeout} = $self->{macro_delay} unless defined $self->{mainline_delay} && defined $self->{subline_delay}
		}
		else {
			my ($tmp) = $line =~ /^pause\s*(.*)/;
			if (defined $tmp) {
				my $result = parseCmd($tmp, $self);
				if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
				unless (defined $result) {$self->{error} = "$errtpl: $tmp failed"}
				else {$self->{timeout} = $result}
			}
			else {$self->{timeout} = $self->{macro_delay}}
		}
		$self->{line}++;
		return $self->{result} if $self->{result}
	##########################################
	# stop command
	} elsif ($line eq "stop") {
		$self->{finished} = 1
	##########################################
	# release command
	} elsif ($line =~ /^release\s+/) {
		if ($line =~ /;/) {run_sublines($line, $self); if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}}
		else {
			my ($tmp) = $line =~ /^release\s+(.*)/;
			my $automacro = $eventMacro->{Automacro_List}->getByName(parseCmd($tmp, $self));
			if (!$automacro) {
				if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
				$self->{error} = "$errtpl: releasing $tmp failed"
			} else {
				$automacro->enable();
			}
		}
		$self->{line}++;
		$self->{timeout} = 0 unless defined $self->{mainline_delay} && defined $self->{subline_delay};
		return $self->{result} if $self->{result}
	##########################################
	# lock command
	} elsif ($line =~ /^lock\s+/) {
		if ($line =~ /;/) {run_sublines($line, $self); if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}}
		else {
			my ($tmp) = $line =~ /^lock\s+(.*)/;
			my $automacro = $eventMacro->{Automacro_List}->getByName(parseCmd($tmp, $self));
			if (!$automacro) {
				if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
				$self->{error} = "$errtpl: locking $tmp failed"
			} else {
				$automacro->disable();
			}
		}
		$self->{line}++;
		$self->{timeout} = 0 unless defined $self->{mainline_delay} && defined $self->{subline_delay};
		return $self->{result} if $self->{result}
	##########################################
	# call command
	} elsif ($line =~ /^call\s+/) {
		my ($tmp) = $line =~ /^call\s+(.*)/;
		my $name = $tmp;
		my $args;
		my $cparms;
		
		my $calltimes = 1;
		
		if ($tmp =~ /\s/) {
			($name, $args) = $tmp =~ /^(\S+?)\s+(.+)/;
			my ($times);
			if ($args =~ /(\d+)\s+(--.*)/) {
				($times, $cparms) = $args =~ /(\d+)?\s+?(--.*)?/;
				$times = parseCmd($args, $self);
				$cparms = parseCmd($args, $self);
			} elsif ($args =~ /^\d+/) {
				$times = parseCmd($args, $self);
			}  elsif ($args =~ /^--.*/) {
				$cparms = parseCmd($args, $self);
			}

			if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
			if (defined $times && $times =~ /\d+/) { $calltimes = $times; }; # do we have a valid repeat value?
		}
		
		$self->{subcall} = eventMacro::Runner->new($name, $calltimes, undef, undef, $self->{interruptible});
		
		unless (defined $self->{subcall}) {
			$self->{error} = "$errtpl: failed to call script";
		} else {
			my @new_params = substr($cparms, 2) =~ /"[^"]+"|\S+/g;
			foreach my $p (1..@new_params) {
				$eventMacro->set_var(".param".$p,$new_params[$p-1]);
				$eventMacro->set_var(".param".$p,substr($eventMacro->get_var(".param".$p), 1, -1)) if ($eventMacro->get_var(".param".$p) =~ /^".*"$/);
			}
			
			$self->{subcall}->regSubmacro;
			$self->{line}++; # point to the next line to be executed in the caller
			$self->{timeout} = $self->{macro_delay};
		}
	##########################################
	# set command
	} elsif ($line =~ /^set\s+/) {
		if ($line =~ /;/) {run_sublines($line, $self); if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}}
		else {
			my ($var, $val) = $line =~ /^set\s+(\w+)\s+(.*)$/;
			if ($var eq 'macro_delay' && $val =~ /^[\d\.]*\d+$/) {
				$self->{macro_delay} = $val
			} elsif ($var eq 'repeat' && $val =~ /^\d+$/) {
				$self->{repeat} = $val
			} elsif ($var eq 'overrideAI' && $val =~ /^[01]$/) {
				$self->{overrideAI} = $val
			} elsif ($var eq 'exclusive' && $val =~ /^[01]$/) {
				$self->{interruptible} = $val?0:1
			} elsif ($var eq 'orphan' && $val =~ /^(?:terminate|reregister(?:_safe)?)$/) {
				$self->{orphan} = $val
			} else {
				$self->{error} = "$errtpl: unrecognized key or wrong value"
			}
		}
		$self->{line}++;
		$self->{timeout} = 0 unless defined $self->{mainline_delay} && defined $self->{subline_delay};
		return $self->{result} if $self->{result}
	##########################################
	# sub-routine command, still figuring out how to include unclever/fail sub-routine into the error msg
	} elsif ($line =~ /^(?:\w+)\s*\(.*?\)/) {
		if ($line =~ /;/) {run_sublines($line, $self)}
		else {
			parseCmd($line, $self);
		}
		if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
		$self->{line}++;
		$self->{timeout} = 0 unless defined $self->{mainline_delay} && defined $self->{subline_delay};
		return $self->{result} if $self->{result}
	##########################################
	# unrecognized line
	} else {
		$self->{error} = "$errtpl: syntax error"
	}
	
	if (defined $self->{error}) {return} else {return ""}
}


sub run_sublines {
	my ($real_line, $self) = @_;
	my ($i, $real_num, @sub_line) = (0, $self->{line}, undef);
	my @split = split(/\s*;\s*/, $real_line);
	my ($dvar, $var, $val, $list);
	
	foreach my $e (@split) {
		next if $e eq "";
		if (defined $self->{subline_delay} && $i < $self->{subline_delay}) {$i++; next}
		if (defined $self->{subline_delay} && $i == $self->{subline_delay}) {
			$self->{timeout} = 0;
			($self->{mainline_delay}, $self->{subline_delay}, $self->{result}) = undef;
			$i++; next
		}
		

		# set variable: $variable = value
		if ($e =~ /^\$[a-z]/i) {
			if (($var, $val) = $e =~ /^\$([a-z][a-z\d]*?)\s+=\s+(.*)/i) {
				my $pval = parseCmd($val, $self);
				if (defined $self->{error}) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: $self->{error}"; last}
				if (defined $pval) {
					if ($pval =~ /^\s*(?:undef|unset)\s*$/i && $eventMacro->exists_var($var)) {$eventMacro->set_var($var, 'undef')}
					else {$eventMacro->set_var($var,$pval)}
				}
				else {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: $e failed"; last}
			}
			elsif (($var, $val) = $e =~ /^\$([a-z][a-z\d]*?)([+-]{2})$/i) {
				if ($val eq '++') {
					if ($eventMacro->is_var_defined($var)) {
						$eventMacro->set_var($var, ($eventMacro->get_var($var)+1));
					} else {
						$eventMacro->set_var($var, 1);
					}
				} else {
					if ($eventMacro->is_var_defined($var)) {
						$eventMacro->set_var($var, ($eventMacro->get_var($var)-1));
					} else {
						$eventMacro->set_var($var, -1);
					}
				}
			}
			else {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: unrecognized assignment in ($e)"; last}
			$i++; next
		# stop command
		} elsif ($e eq "stop") {
			$self->{finished} = 1; last
		
		# set command
		} elsif (($var, $val) = $e =~ /^set\s+(\w+)\s+(.*)$/) {
			if ($var eq 'macro_delay' && $val =~ /^[\d\.]*\d+$/) {$self->{macro_delay} = $val}
			elsif ($var eq 'repeat' && $val =~ /^\d+$/) {$self->{repeat} = $val}
			elsif ($var eq 'overrideAI' && $val =~ /^[01]$/) {$self->{overrideAI} = $val}
			elsif ($var eq 'exclusive' && $val =~ /^[01]$/) {$self->{interruptible} = $val?0:1}
			elsif ($var eq 'orphan' && $val =~ /^(?:terminate|reregister(?:_safe)?)$/) {$self->{orphan} = $val}
			else {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: unrecognized key or wrong value in ($e)"; last}
				
		# lock command
		} elsif ($e =~ /^lock\s+/) {
			my ($tmp) = $e =~ /^lock\s+(.*)/;
			my $automacro = $eventMacro->{Automacro_List}->getByName(parseCmd($tmp, $self));
			if (!$automacro) {
				if (defined $self->{error}) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: $self->{error}"; last}
				$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: locking $tmp failed in ($e)"; last
			} else {
				$automacro->disable();
			}
			
				
		# release command
		} elsif ($e =~ /^release\s+/) {
			my ($tmp) = $e =~ /^release\s+(.*)/;
			my $automacro = $eventMacro->{Automacro_List}->getByName(parseCmd($tmp, $self));
			if (!$automacro) {
				if (defined $self->{error}) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: $self->{error}"; last}
				$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: releasing $tmp failed in ($e)"; last
			} else {
				$automacro->enable();
			}
		
		# pause command
		} elsif ($e =~ /^pause/) {
			my ($tmp) = $e =~ /^pause\s*(.*)/;
			if (defined $tmp) {
				my $result = parseCmd($tmp, $self);
				if (defined $self->{error}) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: $self->{error}"; last}
				unless (defined $result) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: $tmp failed in ($e)"; last}
				else {$self->{timeout} = $result}
			}
			else {$self->{timeout} = $self->{macro_delay}}
			$self->{mainline_delay} = $real_num;
			$self->{subline_delay} = $i;
			last
		
		# log command
		} elsif ($e =~ /^log\s+/) {
			my ($tmp) = $e =~ /^log\s+(.*)/;
			my $result = parseCmd($tmp, $self);
			if (defined $self->{error}) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: $self->{error}"; last}
			unless (defined $result) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: $tmp failed in ($e)"; last}
			else {message "[eventMacro log] $result\n", "eventMacro"}
			$self->{timeout} = $self->{macro_delay};
			$self->{mainline_delay} = $real_num;
			$self->{subline_delay} = $i;
			last
		}
		
		# do command
		elsif ($e =~ /^do\s/) {
			my ($tmp) = $e =~ /^do\s+(.*)/;
			if ($tmp =~ /^macro\s+/) {
				my ($arg) = $tmp =~ /^macro\s+(.*)/;
				if ($arg =~ /^reset/) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: use 'release' instead of 'macro reset'"}
				elsif ($arg eq 'pause' || $arg eq 'resume') {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: do not use 'macro pause' or 'macro resume' within a macro"}
				elsif ($arg =~ /^set\s/) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: do not use 'macro set'. Use \$foo = bar"}
				elsif ($arg eq 'stop') {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: use 'stop' instead"}
				elsif ($arg !~ /^(?:list|status)$/) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: use 'call $arg' instead of 'macro $arg'"}
			}
			elsif ($tmp =~ /^eval\s+/) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: do not mix eval in the sub-line"}
			elsif ($tmp =~ /^ai\s+clear$/) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: do not mess around with ai in macros"}
			my $result = parseCmd($tmp, $self);
			if (defined $self->{error}) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: $self->{error}"; last}
			unless (defined $result) {$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: command $tmp failed"; last}
			$self->{timeout} = $self->{macro_delay};
			$self->{mainline_delay} = $real_num;
			$self->{subline_delay} = $i;
			$self->{result} = $result;
			last
							
		# "call", "[", "]", ":", "if", "while", "end" and "goto" commands block
		} elsif ($e =~ /^(?:call|\[|\]|:|if|end|goto|while)\s*/i) {
			$self->{error} = "Line $real_num sub-line $i\n[Reason:] Use saperate line for HERE --> $e <-- HERE";
			last
		# sub-routine
		} elsif (my ($sub) = $e =~ /^(\w+)\s*\(.*?\)$/) {
			parseCmd($e, $self);
			$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: $self->{error}" if defined $self->{error};
			last	
		
		##################### End ##################
		} else {
			#$self->{error} = "Error in line $real_num: $real_line\n[macro] $self->{Name} error in sub-line $i: unrecognized assignment in ($e)"
			message "Error in $self->{line}: $real_line\nWarning: Ignoring Unknown Command in sub-line $i: ($e)\n", "menu";
		}
		$i++
	}
}

sub newThen {
	my ($then, $self, $errtpl) = @_;

	if ($then =~ /^goto\s/) {
		my ($tmp) = $then =~ /^goto\s+([a-zA-Z][a-zA-Z\d]*)$/;
		if (exists $self->{label}->{$tmp}) {
			$self->{line} = $self->{label}->{$tmp}
		}
		else {$self->{error} = "$errtpl: cannot find label $tmp"}
	}
	elsif ($then =~ /^call\s+/) {
		my ($tmp) = $then =~ /^call\s+(.*)/;
		if ($tmp =~ /\s/) {
			my ($name, $times) = $tmp =~ /(.*?)\s+(.*)/;
			my $ptimes = parseCmd($times, $self);
			if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
			if (defined $ptimes && $ptimes =~ /^\d+$/) {
				if ($ptimes > 0) {
					$self->{subcall} = new eventMacro::Runner($name, $ptimes, $self->{Name}, $self->{line}, $self->{interruptible})
				}
				else {$self->{subcall} = new eventMacro::Runner($name, 0, undef, undef, $self->{interruptible})}
			}
			else {$self->{error} = "$errtpl: $ptimes must be numeric"}
		}
		else {$self->{subcall} = new eventMacro::Runner($tmp, 1, undef, undef, $self->{interruptible})}
		unless (defined $self->{subcall}) {$self->{error} = "$errtpl: failed to call script"}
		else {
			$self->{subcall}->regSubmacro;
			$self->{timeout} = $self->{macro_delay}
		}
	}
	elsif ($then eq "stop") {$self->{finished} = 1}
}


sub statement {
	my ($temp_multi, $self, $errtpl) = @_;
	my ($first, $cond, $last) = $temp_multi =~ /^\s*"?(.*?)"?\s+([<>=!~]+?)\s+"?(.*?)"?\s*$/;
	if (!defined $first || !defined $cond || !defined $last) {$self->{error} = "$errtpl: syntax error in if statement"}
	else {
		my $pfirst = parseCmd(refined_macroKeywords($first), $self); my $plast = parseCmd(refined_macroKeywords($last), $self);
		if (defined $self->{error}) {$self->{error} = "$errtpl: $self->{error}"; return}
		unless (defined $pfirst && defined $plast) {$self->{error} = "$errtpl: either '$first' or '$last' has failed"}
		elsif (cmpr($pfirst, $cond, $plast)) {return 1}
	}
	return 0
}

sub particle {
	# I need to test this main code alot becoz it will be disastrous if something goes wrong
	# in the if statement block below

	my ($text, $self, $errtpl) = @_;
	my @brkt;

	if ($text =~ /\(/) {
		@brkt = txtPosition($text, $self, $errtpl);
		$brkt[0] = multi($brkt[0], $self, $errtpl) if !bracket($brkt[0]) && $brkt[0] =~ /[\(\)]/ eq "";
		$text = extracted($text, @brkt);
	}

	unless ($text =~ /\(/) {return $text}
	$text = particle($text, $self, $errtpl)
}

sub multi {
	my ($text, $self, $errtpl) = @_;
	my ($i, $n, $ok, $ok2) = (0, 0, 1, 0);
	my %save;

	while ($text =~ /(\|{2}|\&{2})/g) {
		# Check if we put the wrong '&&' or '||' in the statement
		# Logically, each clean statement(none-bracket statement),
		# cant use the simbol '&&' or '||' together. Infact, it must be saperated
		# by using round brackets '(' and ')' in the 1st place

		$save{$i} = $1;
		if ($i > 0) {
			$n = $i - 1;
			if ($save{$i} ne $save{$n}) {
				my $s = $text;
				$ok = 0;
				#$s =~ s/($save{$i})/\($1\) <-- HERE/g;    # Later maybe? ;p
				$self->{error} = "Wrong Conditions: $errtpl ($save{$n} vs $save{$i})"
			}
		}
		$i++
	}

	if ($save{$n} eq "||" && $ok && $i > 0) {
		my @split = split(/\s*\|{2}\s*/, $text);
		foreach my $e (@split) {
			next if $e eq "0";
			return 1 if $e eq "1";
			return 1 if statement($e, $self, $errtpl)
		}
		return 0
	}
	elsif ($save{$n} eq "&&" && $ok && $i > 0) {
		my @split = split(/\s*\&{2}\s*/, $text);
		foreach my $e (@split) {
			next if $e eq "1";
			return 0 if $e eq "0";
			next if statement($e, $self, $errtpl);
			return 0
		}
		return 1
	}
	elsif ($i == 0) {
		return $text if $text =~ /^[0-1]$/;
		return statement($text, $self, $errtpl)
	}
}

sub txtPosition {
	# This sub will deal which bracket is belongs to which statement,
	# Using this, will capture the most correct statement to be checked 1st before the next statement,
	# Ex: ((((1st statement)2nd statement)3rd statement)4th statement)
	# will return: $new[0] = "1st statement", $new[1] = 4, $new[2] = 16
   
	my ($text, $self, $errtpl) = @_;
	my ($start, $i) = (0, 0);
	my (@save, @new, $first, $last);
	my @w = split(//, $text);

	foreach my $e (@w) {
		if ($e eq ")" && $start) {
			 $last = $i; last
		}
		elsif ($e eq "(") {
			if ($start) {undef @save; undef $first}
			$start = 1; $first = $i;
		}
		else {if ($start) {push @save, $e}}
		$i++
	}

	$self->{error} = "$errtpl: You probably missed 1 or more closing round-\nbracket ')' in the statement." if !defined $last;

	$new[0] = join('', @save);
	$new[1] = $first;
	$new[2] = $last;
	return @new
}

sub extracted {
	# Normally we just do substract s/// or s///g or using while grouping for s{}{} to delete or replace...
	# but for some cases, the perl substract is failed... atleast for this text
	# ex: $text = "(1 || 0) && 1 && 0" (or I might missed some info for the substract function?)
	# so, below code will simply ignore the (1 || 0) but will replace it with $brkt[0] which is either 1 or 0,
	# in return, the new $text will be in this format: $text = "1 && 1 && 0" if the $brkt[0] happened to be 1.

	my ($text, @brkt) = @_;
	my @save;
	my @w = split(//, $text);

	my $txt_length = scalar(@w);

	for (my $i = 0; $i < $txt_length; $i++) {
		if ($i == $brkt[1]) {push @save, $brkt[0]; next}
		next if $i > $brkt[1] && $i <= $brkt[2];
		push @save, $w[$i];
		next
	}
	
	$text = join('', @save);
	return $text
}

sub refined_macroKeywords {
	# To make sure if there is really no more @special keywords

	my @pair = $_[0] =~ /\@($macroKeywords)\s*\(\s*(.*)\s*\)/i;
	return $_[0] unless @pair;

	$pair[1] = parseCmd($pair[1]);
	my $new = "@".$pair[0]."(".$pair[1].")";	#sorry! cheap code ;p
	return $new
}

sub bracket {
	# Scans $text for @special keywords

	my ($text, $dbg) = @_;
	my @brkt; my $i = 0;

	while ($text =~ /(\@)?($macroKeywords)?\s*\(\s*([^\)]+)\s*/g) {
		my ($first, $second, $third) = ($1, $2, $3);
		unless (defined $first && defined $second && !bracket($third, 1)) {
			message "Bracket Detected: $text <-- HERE\n", "menu" if $dbg;
			$brkt[$i] = 1
		}
		else {$brkt[$i] = 0}
		$i++
	}

	foreach my $e (@brkt) {
		if ($e == 1) {return 1}
	}

	return 0
}

1;