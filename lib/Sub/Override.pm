package Sub::Override;

use strict;
use warnings;

our $VERSION = '0.04';

my $_croak = sub {
    local *__ANON__ = '__ANON__croak';
    my ($proto, $message) = @_;
    require Carp;
    Carp::croak($message);
};

my $_validate_code_slot = sub {
    local *__ANON__ = '__ANON__validate_code_slot';
    my ($self, $code_slot) = @_;
    no strict 'refs';
    unless (defined *{$code_slot}{CODE}) {
        $self->$_croak("Cannot replace non-existent sub ($code_slot)");
    }
    return $self;
};

my $_validate_sub_ref = sub {
    local *__ANON__ = '__ANON__validate_sub_ref';
    my ($self, $sub_ref) = @_;
    unless ('CODE' eq ref $sub_ref) {
        $self->$_croak("($sub_ref) must be a code reference");
    }   
    return $self;
};

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->replace(@_) if @_;
    return $self;
}

my $_normalize_sub_name = sub {
    my ($self, $subname) = @_;
    if (($subname || '') =~ /^\w+$/) { # || "" for suppressing test warnings
        my $package = do {
            my $call_level = 0;
            my $this_package;
            while (! $this_package || __PACKAGE__ eq $this_package) {
                ($this_package) = caller($call_level);
                $call_level++;
            }
            $this_package;
        };
        $subname = "${package}::$subname";
    }
    return $subname;
};

sub replace {
    my ($self, $sub_to_replace, $new_sub) = @_;
    $sub_to_replace = $self->$_normalize_sub_name($sub_to_replace);
    $self->$_validate_code_slot($sub_to_replace)
         ->$_validate_sub_ref($new_sub);
    {
        no strict 'refs';
        $self->{$sub_to_replace} = *$sub_to_replace{CODE};
        no warnings 'redefine';
        *$sub_to_replace = $new_sub;
    }
    return $self;
}

sub restore {
    my ($self, $name_of_sub) = @_;
    $name_of_sub = $self->$_normalize_sub_name($name_of_sub);
    if (! $name_of_sub && 1 == keys %$self) {
        ($name_of_sub) = keys %$self;
    }
    $self->$_croak(
        sprintf 'You must provide the name of a sub to restore: (%s)' =>
            join ', ' => sort keys %$self
    ) unless $name_of_sub;
    $self->$_croak("Cannot restore a sub that was not replaced ($name_of_sub)")
        unless exists $self->{$name_of_sub};
    no strict 'refs';
    no warnings 'redefine';
    *$name_of_sub = delete $self->{$name_of_sub};
    return $self;
}

sub DESTROY {
    my $self = shift;
    no strict 'refs';
    no warnings 'redefine';
    while (my ($sub_name, $sub_ref) = each %$self) {
        *$sub_name = $sub_ref;
    }
}

1;

__END__

=head1 NAME

Sub::Override - Perl extension for easily overriding subroutines

=head1 SYNOPSIS

  use Sub::Override;

  sub foo { 'original sub' };
  print foo(); # prints 'original sub'

  my $override = Sub::Override->new( foo => sub { 'overridden sub' } );
  print foo(); # prints 'overridden sub'
  $override->restore;
  print foo(); # prints 'original sub'

=head1 DESCRIPTION

=head2 The Problem

Sometimes subroutines need to be overridden.  In fact, your author does this
constantly for tests.  Particularly when testing, using a Mock Object can be
overkill when all you want to do is override one tiny, little function.

Overriding a subroutine is often done with syntax similar to the following.

 {
   local *Some::sub = sub {'some behavior'};
   # do something
 }
 # original subroutine behavior restored

This has a few problems.

 {
   local *Get::some_feild = { 'some behavior' };
   # do something
 }

In the above example, not only have we probably mispelled the subroutine name,
but even if their had been a subroutine with that name, we haven't overridden
it.  These two bugs can be subtle to detect.

Further, if we're attempting to localize the effect by placing this code in a
block, the entire construct is cumbersome.

Hook::LexWrap also allows us to override sub behavior, but I can never remember
the exact syntax.

=head2 An easier way to replace subroutines

Instead, C<Sub::Override> allows the programmer to simply name the sub to
replace and to supply a sub to replace it with.

  my $override = Sub::Override->new('Some::sub', sub {'new data'});

  # which is equivalent to:
  my $override = Sub::Override->new;
  $override->replace('Some::sub', sub { 'new data' });

You can replace multiple subroutines, if needed:

  $override->replace('Some::sub1', sub { 'new data1' })
           ->replace('Some::sub2', sub { 'new data2' })
           ->replace('Some::sub3', sub { 'new data3' });

(Chaining calls is not required)

=head2 Restoring subroutines

If the object falls out of scope, the original subs are restored.  However, if
you need to restore a subroutine early, just use the restore method:

  my $override = Sub::Override->new('Some::sub', sub {'new data'});
  # do stuff
  $override->restore;

Which is somewhat equivalent to:

  {
    my $override = Sub::Override->new('Some::sub', sub {'new data'});
    # do stuff
  }

If you have override more than one subroutine with an override object, you
will have to explicitly name the subroutine you wish to restore:

  $override->restore('This::sub');

Failure to fully qualify the subroutine name will assume the current package.

  package Foo;
  use Sub::Override;
  sub foo { 23 };
  my $override = Sub::Override->new( foo => sub { 42 } ); # assumes Foo::foo
  print foo(); # prints 42
  $override->restore;
  print foo(); # prints 23

=head1 EXPORT

None by default.

=head1 BUGS

Probably.  Tell me about 'em.

=head1 SEE ALSO

=over 4

=item *
Hook::LexWrap -- can also override subs, but with different capabilities

=item *
Test::MockObject -- use this if you need to alter an entire class

=back

=head1 AUTHOR

Curtis "Ovid" Poe, E<lt>eop_divo_sitruc@yahoo.comE<gt>

Reverse the name to email me.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Curtis "Ovid" Poe

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
