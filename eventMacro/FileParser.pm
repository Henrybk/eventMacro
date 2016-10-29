package eventMacro::FileParser;

use strict;
use encoding 'utf8';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(parseMacroFile isNewCommandBlock);
our @EKSPORT_OK = qw(isNewCommandBlock);

use Globals;
use Utils qw/existsInList/;
use Utils::Exceptions;
use List::Util qw(max min sum);
use Log qw(message error warning debug);
use Text::Balanced qw/extract_bracketed/;

use eventMacro::Core;
use eventMacro::Data;
use eventMacro::Lists;
use eventMacro::Automacro;
use eventMacro::FileParser;
use eventMacro::Macro;




my $tempmacro = 0;
my %macro;
my %automacro;

sub parseMacroFile {
	my ($file, $recursive) = @_;
	
	unless ($recursive) {
		undef %macro;
		undef %automacro;
		undef @perl_name
	}

	my %block;
	my $inBlock = 0;
	my $macroCountOpenBlock = 0;
	my ($macro_subs, @perl_lines);
	open my $fp, "<:utf8", $file or return 0;
	while (<$fp>) {
		$. == 1 && 
		s/^\x{FEFF}//;          # utf bom
		s/(.*)[\s\t]+#.*$/$1/;	# remove last comments
		s/^\s*#.*$//;		    # remove comments
		s/^\s*//;               # remove leading whitespaces
		s/\s*[\r\n]?$//g;    	# remove trailing whitespaces and eol
		s/  +/ /g;		        # trim down spaces - very cool for user's string data?
		next unless ($_);

		if (!%block && /{$/) {
			my ($key, $value) = $_ =~ /^(.*?)\s+(.*?)\s*{$/;
			if ($key eq 'macro') {
				%block = (name => $value, type => "macro");
				$macro{$value} = [];
			} elsif ($key eq 'automacro') {
				%block = (name => $value, type => "automacro");
			} elsif ($key eq 'sub') {
				%block = (name => $value, type => "sub");
			} else {
				%block = (type => "bogus");
				warning "$file: ignoring line '$_' in line $. (munch, munch, strange block)\n";
			}
			next;




		} elsif (%block && $block{type} eq "bogus") {
			if ($_ eq "}") {undef %block}
			next;




		} elsif (%block && $block{type} eq "macro") {
			if ($_ eq "}") {
				if ($macroCountOpenBlock) {
					push(@{$macro{$block{name}}}, '}');
					$macroCountOpenBlock--;
				} else {
					undef %block;
				}
			} else {
				if (isNewCommandBlock($_)) {
					$macroCountOpenBlock++
				} elsif (!$macroCountOpenBlock && isNewWrongCommandBlock($_)) {
					warning "$file: ignoring '$_' in line $. (munch, munch, not found the open block command)\n";
					next;
				}
				push(@{$macro{$block{name}}}, $_);
			}
			
			next;



			
		} elsif (%block && $block{type} eq "automacro") {
			if ($_ eq "}") {
				if ($block{loadmacro}) {
					if ($macroCountOpenBlock) {
						push(@{$macro{$block{loadmacro_name}}}, '}');
						
						if ($macroCountOpenBlock) {
							$macroCountOpenBlock--;
						}
					} else {
						undef $block{loadmacro}
					}
				} else {
					undef %block
				}
			} elsif ($_ eq "call {") {
				$block{loadmacro} = 1;
				$block{loadmacro_name} = "tempMacro".$tempmacro++;
				push(@{$automacro{$block{name}}{parameters}}, {key => 'call', value => $block{loadmacro_name}});
				$macro{$block{loadmacro_name}} = []
			} elsif ($block{loadmacro}) {
				if (isNewCommandBlock($_)) {
					$macroCountOpenBlock++
				} elsif (!$macroCountOpenBlock && isNewWrongCommandBlock($_)) {
					warning "$file: ignoring '$_' in line $. (munch, munch, not found the open block command)\n";
					next
				}

				push(@{$macro{$block{loadmacro_name}}}, $_);
			} else {
				my ($key, $value) = $_ =~ /^(.*?)\s+(.*)/;
				if (!defined $key || !defined $value) {
					warning "$file: ignoring '$_' in line $. (munch, munch, not a pair)\n";
					next;
				}
				if (exists $parameters{$key}) {
					push(@{$automacro{$block{name}}{parameters}}, {key => $key, value => $value});
				} else {
					push(@{$automacro{$block{name}}{conditions}}, {key => $key, value => $value});
				}
			}
			
			next;




		} elsif (%block && $block{type} eq "sub") {
			if ($_ eq "}") {
				if ($inBlock > 0) {
					push(@perl_lines, $_);
					$inBlock--;
					next
				}
				$macro_subs = join('', @perl_lines);
				sub_execute($block{name}, $macro_subs);
				push(@perl_name, $block{name}) unless existsInList(join(',', @perl_name), $block{name});
				undef %block; undef @perl_lines; undef $macro_subs;
				$inBlock = 0
			}
			elsif ($_ =~ /^}.*?{$/ && $inBlock > 0) {push(@perl_lines, $_)}
			elsif ($_ =~ /{$/) {$inBlock++;	push(@perl_lines, $_)}
			else {push(@perl_lines, $_)}
			next;




		}

		my ($key, $value) = $_ =~ /(?:^(.*?)\s|})+(.*)/;
		unless (defined $key) {
			warning "$file: ignoring '$_' in line $. (munch, munch, strange food)\n";
			next
		}

		if ($key eq "!include") {
			my $f = $value;
			if (!File::Spec->file_name_is_absolute($value) && $value !~ /^\//) {
				if ($file =~ /[\/\\]/) {
					$f = $file;
					$f =~ s/(.*)[\/\\].*/$1/;
					$f = File::Spec->catfile($f, $value)
				} else {
					$f = $value
				}
			}
			if (-f $f) {
				my $ret = parseMacroFile($f, 1);
				return $ret unless $ret
			} else {
				error "$file: Include file not found: $f\n";
				return 0
			}
		}
	}
	
	close $fp;
	return 0 if %block;
	return {macros => \%macro, automacros => \%automacro};
}

sub sub_execute {
	return if $Settings::lockdown;
	
	my ($name, $arg) = @_;
	my $run = "sub ".$name." {".$arg."}";
	eval($run);			# cycle the macro sub between macros only
	$run = "eval ".$run;
	Commands::run($run);		# exporting sub to the &main::sub, becarefull on your sub name
					# dont name your new sub equal to any &main::sub, you should take
					# the risk yourself.
	message "[eventMacro] registering sub '".$name."'.\n", "menu";
}

# check if on the line there commands that open new command blocks
sub isNewCommandBlock {
	my ($line) = @_;
	
	if ($line =~ /^if.*{$/ || $line =~ /^case.*{$/ || $line =~ /^switch.*{$/ || $line =~ /^else.*{$/) {
		return 1;
	} else {
		return 0;
	}
}

sub isNewWrongCommandBlock {
	my ($line) = @_;
	
	if ($_ =~ /^}\s*else\s*{$/ || $_ =~ /}\s*elsif.*{$/ || $_ =~ /^case.*{$/ || $_ =~ /^else*{$/) {
		return 1;
	} else {
		return 0;
	}
}

1;