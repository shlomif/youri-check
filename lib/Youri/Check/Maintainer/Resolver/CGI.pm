# $Id$
package Youri::Check::Maintainer::Resolver::CGI;

=head1 NAME

Youri::Check::Maintainer::Resolver::CGI - CGI-based maintainer resolver

=head1 DESCRIPTION

This is a CGI-based L<Youri::Check::Maintainer::Resolver> implementation.

It uses a remote CGI to resolve maintainers.

=cut

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
use Carp;
use Youri::Check::WebRetriever;
use Youri::Types qw/URI/;

extends 'Youri::Check::Maintainer::Resolver';

has 'url' => ( is => 'ro', isa => URI );

=head1 CLASS METHODS

=head2 new(%args)

Creates and returns a new Youri::Check::Maintainer::Resolver::CGI object.

Specific parameters:

=over

=item url $url

CGI's URL.

=back

=cut

sub BUILD {
    my ($self, $params) = @_;

    my $retriever = Youri::Check::WebRetriever->new(
        url     => $params->{url},
        pattern => qr/^(\S+)\t(\S+)$/,
    );

    $self->{_maintainers} = $retriever->get_results();
}

sub get_maintainer {
    my ($self, $package) = @_;
    croak "Not a class method" unless ref $self;

    print "Retrieving package $package maintainer\n"
        if $self->{_verbose} > 0;

    my $name = ref $package && $package->isa('Youri::Package') ?
        $package->get_canonical_name() :
        $package;

    return $self->{_maintainers}->{$name};
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2002-2006, YOURI project

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;
