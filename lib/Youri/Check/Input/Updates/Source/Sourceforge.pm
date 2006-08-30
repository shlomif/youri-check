# $Id$
package Youri::Check::Input::Updates::Source::Sourceforge;

=head1 NAME

Youri::Check::Input::Updates::Source::Sourceforge - Sourceforge updates source

=head1 DESCRIPTION

This source plugin for L<Youri::Check::Input::Updates> collects updates
available from Sourceforge.

=cut

use warnings;
use strict;
use Carp;
use LWP::UserAgent;
use HTML::TokeParser;
use Youri::Check::Input::Updates;
use base 'Youri::Check::Input::Updates::Source';

=head2 new(%args)

Creates and returns a new Youri::Check::Input::Updates::Source::Sourceforge
object.  

No specific parameters.

=cut

sub _init {
    my $self    = shift;
    my %options = (
        @_
    );

    $self->{_agent} = LWP::UserAgent->new();
}

sub get_version {
    my ($self, $package) = @_;
    croak "Not a class method" unless ref $self;

    my $name;
    if (ref $package && $package->isa('Youri::Package')) {
        # don't bother checking for packages without sf.net URL
        my $url = $package->get_url();
        if (
            $url =~ /http:\/\/(.*)\.sourceforge\.net/ ||
            $url =~ /http:\/\/.*sourceforge\.net\/projects\/([^\/]+)/
        ) {
            $name = $package->get_canonical_name();
        } else {
            return;
        }
    } else {
        $name = $package;
    }

    # translate in grabber namespace
    $name = $self->get_name($name);

    # return if aliased to null 
    return unless $name;

    my $response = $self->{_agent}->get($self->_url($name));
    if($response->is_success()) {
        my $max = 0;
        my $parser = HTML::TokeParser->new(\$response->content());
        while (my $token = $parser->get_tag('a')) {
            my $text = $parser->get_trimmed_text("/$token->[0]");
            next unless $text;
            next unless $text =~ /^
                \Q$name\E
                [._-]?($Youri::Check::Input::Updates::VERSION_REGEXP)
                [._-]?(w(?:in)?(?:32)?|mips|sparc|bin|ppc|i\d86|src|sources?)?
                \.(?:tar\.(?:gz|bz2)|tgz|zip)
                $/iox;
            my $version = $1;
            my $arch    = $2;
            next if $arch && $arch !~ /(src|sources?)/;
            $max = $version if Youri::Check::Input::Updates::is_newer($version, $max);
        }
        return $max if $max;
    }
    return;
}

sub _url {
    my ($self, $name) = @_;
    return "http://prdownloads.sourceforge.net/$name/";
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2002-2006, YOURI project

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;
