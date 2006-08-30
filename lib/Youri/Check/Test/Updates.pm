# $Id$
package Youri::Check::Test::Updates;

=head1 NAME

Youri::Check::Test::Updates - Check available updates

=head1 DESCRIPTION

This plugin checks available updates for packages, and report existing ones.
Additional source plugins handle specific sources.

=cut

use warnings;
use strict;
use Carp;
use Memoize;
use Youri::Utils;
use Youri::Check::Descriptor::Row;
use Youri::Check::Descriptor::Cell;
use base 'Youri::Check::Test';

my $descriptor = Youri::Check::Descriptor::Row->new(
    cells => [
        Youri::Check::Descriptor::Cell->new(
            name        => 'package',
            description => 'package',
            mergeable   => 1,
            value       => 'package',
            type        => 'string',
        ),
        Youri::Check::Descriptor::Cell->new(
            name        => 'maintainer',
            description => 'maintainer',
            mergeable   => 1,
            value       => 'maintainer',
            type        => 'email',
        ),
        Youri::Check::Descriptor::Cell->new(
            name        => 'current',
            description => 'current version',
            mergeable   => 0,
            value       => 'current',
            type        => 'string',
        ),
        Youri::Check::Descriptor::Cell->new(
            name        => 'available',
            description => 'available version',
            mergeable   => 0,
            value       => 'available',
            type        => 'string',
        ),
        Youri::Check::Descriptor::Cell->new(
            name        => 'source',
            description => 'information source',
            mergeable   => 0,
            value       => 'source',
            type        => 'string',
            link        => 'url',
        )
    ]
);

sub get_descriptor {
    return $descriptor;
}

memoize('is_newer');

our $VERSION_REGEXP = 'v?([\d._-]*\d)[._ -]*(?:(alpha|beta|pre|rc|pl|rev|cvs|svn|[a-z])[_ -.]*([\d.]*))?([_ -.]*.*)';

=head2 new(%args)

Creates and returns a new Youri::Check::Test::Updates object.

Specific parameters:

=over

=item aliases $aliases

Hash of global aliases definitions

=item sources $sources

Hash of source plugins definitions

=back

=cut

sub _init {
    my $self    = shift;
    my %options = (
        aliases => undef,
        sources => undef,
        @_
    );

    croak "No source defined" unless $options{sources};
    croak "sources should be an hashref" unless ref $options{sources} eq 'HASH';
    if ($options{aliases}) {
        croak "aliases should be an hashref" unless ref $options{aliases} eq 'HASH';
    }

    foreach my $id (keys %{$options{sources}}) {
        print "Creating source $id\n" if $options{verbose};
        eval {
            # add global aliases if defined
            if ($options{aliases}) {
                foreach my $alias (keys %{$options{aliases}}) {
                    $options{sources}->{$id}->{aliases}->{$alias} =
                    $options{aliases}->{$alias}
                }
            }

            push(
                @{$self->{_sources}},
                create_instance(
                    'Youri::Check::Test::Updates::Source',
                    id          => $id,
                    test        => $options{test},
                    verbose     => $options{verbose},
                    check_id    => $options{id},
                    resolver    => $options{resolver},
                    preferences => $options{preferences},
                    %{$options{sources}->{$id}}
                )
            );
        };
        print STDERR "Failed to create source $id: $@\n" if $@;
    }

    croak "no sources created" unless @{$self->{_sources}};
}

sub run {
    my ($self, $media, $resultset) = @_;
    croak "Not a class method" unless ref $self;
    
    # this is a source media check only
    return unless $media->get_type() eq 'source';

    my $callback = sub {
        my ($package) = @_;

        my $name    = $package->get_name();
        my $version = $package->get_version();
        my $release = $package->get_release();

        # compute version with rpm subtilities related to preversions
        my $current_version = ($release =~ /^0\.(\w+)\.\w+$/) ?
            $version . $1 :
            $version;
        my $current_stable = is_stable($current_version);

        my ($max_version, $max_source, $max_url);
        $max_version = $current_version;

        foreach my $source (@{$self->{_sources}}) {
            my $available_version = $source->get_version($package);
            if (
                $available_version &&
                (! $current_stable || is_stable($available_version)) &&
                is_newer($available_version, $max_version)
            ) {
                $max_version = $available_version;
                $max_source  = $source->get_id();
                $max_url     = $source->get_url($name);
            }
        }
        $resultset->add_result($self->{_id}, $media, $package, {
            current   => $current_version,
            available => $max_version,
            source    => $max_source,
            url       => $max_url
        }) if $max_version ne $current_version;
    };

    $media->traverse_headers($callback);
}

=head2 is_stable($version)

Checks if given version is stable.

=cut

sub is_stable {
    my ($version) = @_;
    return $version !~ /alpha|beta|pre|rc|cvs|svn/i;
    
}

=head2 is_newer($v1, $v2)

Checks if $v1 is newer than $v2.

This function will return true only if we are sure this is newer (and not equal).
If we can't compare the versions, a warning will be displayed.

=cut

sub is_newer {
    my ($v1, $v2) = @_;  
    return 0 if $v1 eq $v2;

    # Reject strange cases
    # One is a large number (like date or revision) and the other one not, or
    # has different length
    if (($v1 =~ /^\d{3,}$/ || $v2 =~ /^\d{3,}$/) 
       && (join('0',split(/\d/, $v1."X")) ne join('0',split(/\d/, $v2."X")))) { 
      carp "strange : $v1 vs $v2";
      return 0;
    }

    my %states = (alpha=>-4,beta=>-3,pre=>-2,rc=>-1);
    my $i; $states{$_} = ++$i foreach 'a'..'z';

    if ($v1 =~ /^[\d._-]+$/ && $v2 =~ /^[\d._-]+$/) {
        my @v1 = split(/[._-]/, $v1);
        my @v2 = split(/[._-]/, $v2);
	if (join('',@v1) eq (join '',@v2)) {
          # Might be something like 1.2.0 vs 1.20, usual false positive
          carp "strange : $v1 vs $v2";
          return 0;
        }
        for my $i (0 .. $#v1) {
          $v1[$i] ||= 0;
          $v2[$i] ||= 0;
          return 1 if $v1[$i] > $v2[$i];
          return 0 if $v1[$i] < $v2[$i];
        }
        # When v2 is longer than v1 but start the same, v1 <= v2
        return 0;
    } else {
        my ($num1, $state1, $statenum1, $other1, $num2, $state2, $statenum2, $other2);

        if ($v1 =~ /^$VERSION_REGEXP$/io) {
            ($num1, $state1, $statenum1, $other1) = ($1, "\L$2", $3, $4);
        } else {
            carp "unknown version format $v1";
            return 0;
        }

        if ($v2 =~ /^$VERSION_REGEXP$/io) {
            ($num2, $state2, $statenum2, $other2) = ($1, "\L$2", $3, $4);
        } else {
            carp "unknown version format $v2";
            return 0;
        }

        # If we know the format of only one, there might be an issue, do nothing

        if (($other1 && ! $other2 )||(!$other1 && $other2 )) {
            carp "can't compare $v1 vs $v2";
            return 0;
        }
	
        return 1 if is_newer($num1, $num2);
        return 0 unless $num1 eq $num2;

        # The numeric part is the same but not the end
        
        if ($state1 eq '') {
            return 1 if $state2 =~ /^(alpha|beta|pre|rc)/;
            return 0 if $state2 =~ /^([a-z]|pl)$/;
            carp "unknown state format $state2";
            return 0;
        }

        if ($state2 eq '') {
            return 0 if $state1 =~ /^(alpha|beta|pre|rc)/;
            return 1 if $state1 =~ /^([a-z]|pl)$/;
            carp "unknown state format $state1";
            return 0;
        }

        if ($state1 eq $state2) {
                return 1 if is_newer($statenum1, $statenum2);
                return 0 unless $statenum1 eq $statenum2;
                # If everything is the same except this, just compare it
                # as we have no idea on the format
                return "$other1" gt "$other2";
        }

        my $s1 = 0;
        my $s2 = 0;
        $s1=$states{$state1} if exists $states{$state1};
        $s2=$states{$state2} if exists $states{$state2};
        return $s1>$s2 if ($s1 != 0 && $s2 != 0);
        return 1 if $s1<0 && $state2 =~ /^([a-z]|pl)$/;
        return 0 if $s2<0 && $state1 =~ /^([a-z]|pl)$/;
        carp "unknown case $v1, $v2";
        return 0;
    }
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2002-2006, YOURI project

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;
