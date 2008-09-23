# $Id$
package Youri::Check::Plugin::Test::Updates::Source::Fedora;

=head1 NAME

Youri::Check::Plugin::Test::Updates::Source::Fedora - Fedora updates source

=head1 DESCRIPTION

This source plugin for L<Youri::Check::Plugin::Test::Updates> collects updates
available from Fedora.

=cut

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
use Youri::Check::Types;
use LWP::UserAgent;

extends 'Youri::Check::Plugin::Test::Updates::Source';

has 'url' => (
    is => 'rw',
    isa => 'Uri',
    default => 'http://fr.rpmfind.net/linux/fedora/core/development/source/SRPMS'
);

=head2 new(%args)

Creates and returns a new Youri::Check::Plugin::Test::Updates::Source::Fedora 
object.

Specific parameters:

=over

=item url $url

URL to Fedora development SRPMS directory (default:
http://fr.rpmfind.net/linux/fedora/core/development/source/SRPMS)

=back

=cut

sub BUILD {
    my ($self, $params) = @_;

    my $agent = LWP::UserAgent->new();
    my $buffer = '';
    my $pattern = qr/>([\w-]+)-([\w\.]+)-[\w\.]+\.src\.rpm<\/a>/;
    my $callback = sub {
        my ($data, $response, $protocol) = @_;

        # prepend text remaining from previous run
        $data = $buffer . $data;

        # process current chunk
        while ($data =~ m/(.*)\n/gc) {
            my $line = $1;
            next unless $line =~ $pattern;
            $self->{_versions}->{$1} = $2;
        }

        # store remaining text
        $buffer = substr($data, pos $data);
    };

    $agent->get($self->get_url(), ':content_cb' => $callback);
}

sub _get_package_version {
    my ($self, $name) = @_;
    return $self->{_versions}->{$name};
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2002-2006, YOURI project

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;