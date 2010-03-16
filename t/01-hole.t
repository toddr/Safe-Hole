
use strict;
my $loaded;

BEGIN { $| = 1; print "1..26\n"; }
END {print "not ok 1\n" unless $loaded;}
use Safe::Hole;
use Safe;
use Opcode qw( opmask_add opset );
$loaded = 1;
print "ok 1\n";

# Test construction
my $safe = Safe->new;
my $hole = Safe::Hole->new({});
print "ok 2\n";

# Test visibility of root namespace
our $v;

print (( \$v == $safe->reval('\$v') && !$@ ) ? "not ok 3\n" : "ok 3\n");

sub v { eval '\$v' };

print (( \$v != $hole->call(\&v)) ? "not ok 4\n" : "ok 4\n");

$hole->wrap(sub{ eval '\$v' },$safe,'&v_wrapped');
$safe->share('&v');

print (( \$v == $safe->reval('v()') || $@ ) ? "not ok 5\n" : "ok 5\n");

print (( \$v != $safe->reval('v_wrapped()') || $@ ) ? "not ok 6\n" : "ok 6\n");

# First check Safe works as we expect

my $op = '"Somthing innocuous"';
sub do_op { eval $op; $@ }
$safe->share('&do_op');
print ( $safe->reval('do_op()') ? "not ok 7\n" : "ok 7\n");
$op = 'eval "#Something forbidden"';
print ( !$safe->reval('do_op()') ? "not ok 8\n" : "ok 8\n");

# Check Safe::Hole clears the opmask

$hole->wrap(\&do_op,$safe,'&do_op_wrapped');
print ( $safe->reval('do_op_wrapped()') ? "not ok 9\n" : "ok 9\n");

# Reality: check eof allowed
$op = 'eof';
print ( $safe->reval('do_op()') ? "not ok 10\n" : "ok 10\n");

# Disable one opcode
opmask_add(opset('eof'));
# Make sure that opmask is restored
$hole->call(sub{});

# Disabled opcode propagates into Safe compartment
print ( !$safe->reval('do_op()') ? "not ok 11\n" : "ok 11\n");

# Disabled opcode is not disabled via $hole
print ( $hole->call(\&do_op) ? "not ok 12\n" : "ok 12\n");

# Now create a Safe::Hole with a saved opmask
my $hole2 = Safe::Hole->new({});
print "ok 13\n";

# Sanity check it works at all
print (( 666 != $hole2->call(sub{ 666 })) ? "not ok 14\n" : "ok 14\n");

$op = 'length';
print ( $hole2->call(\&do_op) ? "not ok 15\n" : "ok 15\n");

$op = 'eof';
print ( !$hole2->call(\&do_op) ? "not ok 16\n" : "ok 16\n");

$hole2->wrap(\&do_op,$safe,'&do_op_wrapped2');

# We can still get at forbidden op via $hole...
print ( $safe->reval('do_op_wrapped()') ? "not ok 17\n" : "ok 17\n");
# ...but not via $hole2
print ( !$safe->reval('do_op_wrapped2()') ? "not ok 18\n" : "ok 18\n");

# Check argument and return passing

print (( 5 != $hole2->call(sub{ @{$_[2]} },undef,undef,[ 11 .. 15])) ? "not ok 19\n" : "ok 19\n");
print (( ($hole->call(sub{ map { $_ + shift } 10..15 },20..25))[2] != 34 ) ? "not ok 20\n" : "ok 20\n");

# Check exception handling of die
my $did_not_die;
eval { $hole2->call(sub{die "XXX\n"}); $did_not_die++ };
print (( $did_not_die || $@ ne "XXX\n" ) ? "not ok 21\n" : "ok 21\n");

##############################
# Backward compatible mode
###############################

my $old_hole = new Safe::Hole;
$::v = 'v in main';

print "not " unless $old_hole->call( sub { eval '$v' }) eq 'v in main';
print "ok 22\n";

# Alternate root
my $old_hole2 = new Safe::Hole 'foo';
$foo::v = 'v in foo';
print "not " unless $old_hole2->call( sub { eval '$v' }) eq 'v in foo';
print "ok 23\n";

# Check opcode mask not restored in backward compatible mode
$op='eval "#Something forbidden"'; 
$old_hole->wrap(\&do_op,$safe,'&do_op_wrapped_old');
print "not " unless $safe->reval('do_op_wrapped_old()');
print "ok 24\n";

###################################
# Test that require works
##################################
$hole->wrap(sub { require File::Find; 1 },$safe,'&do_require');
print "not " if $INC{'File/Find.pm'} || !$safe->reval('do_require') || !$INC{'File/Find.pm'};
print "ok 25\n";

##################################
# Test that *INC not localised when it shouldn't be
##################################
$old_hole->wrap(sub { no strict; my $inc='INC'; "@{[%$inc]}" },$safe,'&get_inc');
print "not " unless $safe->reval('%INC = ( FOO => "./FOO.pm" ); &get_inc') eq 'FOO ./FOO.pm';
print "ok 26\n";

###################################
# Test wrapping of objects
##################################

# To do

