# $Id$
package Youri::Check::Input::Updates::Source::Freshmeat;

=head1 NAME

Youri::Check::Input::Updates::Source::Freshmeat - Freshmeat source for updates

=head1 DESCRIPTION

This source plugin for L<Youri::Check::Input::Updates> collects updates
available from Freshmeat.

=cut

use warnings;
use strict;
use Carp;
use XML::Twig;
use LWP::UserAgent;
use base 'Youri::Check::Input::Updates::Source';

=head2 new(%args)

Creates and returns a new Youri::Check::Input::Updates::Source::Freshmeat
object.

Specific parameters:

=over

=item preload true/false

Allows to load full Freshmeat catalogue at once instead of checking each software independantly (default: false)

=back

=cut

sub _init {
    my $self    = shift;
    my %options = (
        preload => 0,
        @_
    );

    if ($options{preload}) {
        my $versions;
        
        my $project = sub {
            my ($twig, $project) = @_;
            my $name    = $project->first_child('projectname_short')->text();
            my $version = $project->first_child('latest_release')->first_child('latest_release_version')->text();
            $versions->{$name} = $version;
            $twig->purge();
        };

        my $twig = XML::Twig->new(
           TwigRoots => { project => $project }
        );

        my $url = 'http://download.freshmeat.net/backend/fm-projects.rdf.bz2';

        open(INPUT, "GET $url | bzcat |") or die "Can't fetch $url: $!\n";
        $twig->parse(\*INPUT);
        close(INPUT);

        $self->{_versions} = $versions;
    }
}

sub _version {
    my ($self, $name) = @_;

    if ($self->{_versions}) {
        return $self->{_versions}->{$name};
    } else {
        my $version;

        my $latest_release_version = sub {
            $version = $_[1]->text();
        };

        my $twig = XML::Twig->new(
            TwigRoots => { latest_release_version => $latest_release_version }
        );

        my $url = "http://freshmeat.net/projects-xml/$name";
        
        open(INPUT, "GET $url |") or die "Can't fetch $url: $!\n";
        # freshmeat answer with an HTML page when project doesn't exist
        $twig->safe_parse(\*INPUT);
        close(INPUT);

        return $version;
    }
}

sub _url {
    my ($self, $name) = @_;
    return "http://freshmeat.net/projects/$name";
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2002-2006, YOURI project

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;
