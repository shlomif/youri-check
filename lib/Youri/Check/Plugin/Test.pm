# $Id$
package Youri::Check::Plugin::Test;

=head1 NAME

Youri::Check::Plugin::Test - Abstract test plugin

=head1 DESCRIPTION

This abstract class defines test plugin interface.

=cut

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
use Youri::Check::Descriptor::Row;
use Youri::Check::Descriptor::Cell;

use constant WARNING => 'warning';
use constant ERROR => 'error';

extends 'Youri::Check::Plugin';

has 'database'    => (
    is => 'rw', isa => 'Youri::Check::Database'
);
has 'resolver'    => (
    is => 'rw', isa => 'Youri::Check::Maintainer::Resolver'
);
has 'preferences' => (
    is => 'rw', isa => 'Youri::Check::Maintainer::Preferences'
);
has 'count' => (
    is => 'rw', isa => 'Int', default => 0
);

sub init {
    my ($self) = @_;

    $self->get_database()->register(
        $self->get_moniker()
    );
}

sub finish {
    my ($self) = @_;

    $self->get_database()->unregister(
        $self->get_moniker(), $self->get_count()
    );
}

sub get_moniker {
    my ($self) = @_;

    no strict 'refs';
    return ${$self->meta()->name() . '::MONIKER'};
}

=head1 CLASS METHODS

=head2 get_descriptor(%args)

Returns the a row descriptor for this test.

=head2 new(%args)

Creates and returns a new Youri::Check::Input object.

No generic parameters (subclasses may define additional ones).

Warning: do not call directly, call subclass constructor instead.

=cut

=head1 INSTANCE METHODS

=head2 prepare(@medias)

Perform optional preliminary initialisation, using given list of
<Youri::Media> objects.

=cut

sub prepare {
    # do nothing
}

=head2 run($media, $resultset)

Check the packages from given L<Youri::Media> object, and store the
result in given L<Youri::Check::Resultset> object.

=head1 SUBCLASSING

The following methods have to be implemented:

=over

=item run

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2002-2006, YOURI project

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;