package Safe::Hole;

require 5.005;
use Carp;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
);
$VERSION = '0.06';

bootstrap Safe::Hole $VERSION;

# Preloaded methods go here.
sub new {
	my($class, $package) = @_;
	my $self = {};
	$self->{PACKAGE} = $package || 'main';
	no strict 'refs';
	$self->{STASH} = \%{$self->{PACKAGE} . '::'};
	bless $self, $class;
}

sub call {
	my($self, $coderef, @args) = @_;
	return _hole_call_sv($self->{STASH}, $coderef, \@args);
}

sub root {
	my $self = shift;
	$self->{PACKAGE};
}

sub wrap {
	my($self, $ref, $cpt, $name) = @_;
	my($result, $typechar, $word);
	no strict 'refs';
	if( $cpt && $name ) {
		croak "Safe object required" unless ref($cpt) eq 'Safe';
		if( $name =~ /^(\W)(\w+(::\w+)*)$/ ) {
			($typechar, $word) = ($1, $2);
		} else {
			croak "'$name' not a valid name";
		}
	}
	my $type = ref $ref;
	if( $type eq '' ) {
		croak "reference required";
	} elsif( $type eq 'CODE' ) {
		$result = sub { $self->call($ref, @_); };
		if( $typechar eq '&' ) {
			*{$cpt->root()."::$word"} = $result;
		} elsif( $typechar ) {
			croak "'$name' type mismatch with $type";
		}
	} elsif( defined %{$type.'::'} ) {
		my $wrapclass = ref($self).'::'.$self->root().'::'.$type;
		*{$wrapclass.'::AUTOLOAD'} = 
			sub {
				$self->call(
					sub {
						no strict;
						my $self = shift;
						my $name = $AUTOLOAD;
						$name =~ s/.*://;
						$self->{OBJ}->$name(@_);
					}, @_);
			} unless defined &{$wrapclass.'::AUTOLOAD'};
		$result = bless { OBJ => $ref }, $wrapclass;
		if( $typechar eq '$' ) {
			${$cpt->varglob($word)} = $result;
		} elsif( $typechar ) {
			croak "'$name' type mismatch with object (must be scalar)";
		}
	} else {
		croak "type '$type' is not supported";
	}
	$result;
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

Safe::Hole - make a hole to the original main compartment in the Safe compartment

=head1 SYNOPSIS

  use Safe;
  use Safe::Hole;
  $cpt = new Safe;
  $hole = new Safe::Hole;
  sub test { Test->test; }
  $Testobj = new Test;
  # $cpt->share('&test');  # alternate as next line
  $hole->wrap(\&test, $cpt, '&test');
  # ${$cpt->varglob('Testobj')} = $Testobj;  # alternate as next line
  $hole->wrap($Testobj, $cpt, '$Testobj');
  $cpt->reval('test; $Testobj->test;'); 
  print $@ if $@;
  package Test;
  sub new { bless {},shift(); }
  sub test { my $self = shift; $self->test2; }
  sub test2 { print "Test->test2 called\n"; }

=head1 DESCRIPTION

  We can call outside defined subroutines from the Safe compartment
using share(), or can call methods through the object that is copied into 
the Safe compartment using varglob(). But that subroutines or methods 
are executed in the Safe compartment too, so they cannot call another 
subroutines that are dinamically qualified with the package name such as 
class methods.
  Through Safe::Hole, we can execute outside defined subroutines in the 
original main compartment from the Safe compartment. 

=head2 Methods

=over 4

=item new [NAMESPACE]

Class method. Constructor. 
  NAMESPACE is the alternate root namespace that 
makes the compartment in which call() method execute the subroutine. 
Default of NAMESPACE means 'main'. We use the default usually.

=item call $coderef [,@args]

Object method. 
  Call the subroutine refered by $coderef in the compartment 
that is specified with constructor new. @args are passed to called
$coderef.

=item wrap $ref [,$cpt ,$name]

Object method. 
  If $ref is a code reference, this method returns the anonymous 
subroutine reference that calls $ref using call() method of Safe::Hole (see 
above). 
  If $ref is a class object, this method makes a wrapper class of that object 
and returns a new object of the wrapper class. Through the wrapper class, 
all original class methods called using call() method of Safe::Hole.
  If $cpt as Safe object and $name as subroutine or scalar name specified, 
this method works like share() method of Safe. When $ref is a code reference
$name must like '&subroutine'. When $ref is a object $name must like '$var'.
  Name $name may not be same as referent of $ref. For example:
  $hole->wrap(\&foo, $cpt, '&bar');
  $hole->wrap(sub{...}, $cpt, '&foo');
  $hole->wrap($objfoo, $cpt, '$objbar');

=back

=item root

Object method. 
  Return the namespace that is specified with constructor new.

=head2 Warning

You MUST NOT share the Safe::Hole object with the Safe compartment. If you do it
the Safe compartment is NOT safe.

=head1 AUTHOR

Sey Nakajima <sey@jkc.co.jp>

=head1 SEE ALSO

Safe(3).

=cut
