# --
# Kernel/System/CRKPI.pm - CR KPIs backend
# Copyright (C) 2003-2013 Carlos Rodríguez
# --
# Based in OTRS file Kernel/System/GenericInterface/Webservice.pm
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CRKPI;

use strict;
use warnings;

use Kernel::System::Valid;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::YAML;

=head1 NAME

Kernel::System::CRKPI - CR KPIs backend

=head1 SYNOPSIS

All CR KPIs functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::Encode;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::DB;
    use Kernel::System::CRKPI;

    my $ConfigObject = Kernel::Config->new();
    my $EncodeObject = Kernel::System::Encode->new(
        ConfigObject => $ConfigObject,
    );
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $KPIObject = Kernel::System::CRKPI->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        DBObject     => $DBObject,
        MainObject   => $MainObject,
        EncodeObject => $EncodeObject,
    );

=cut

sub new {
    my ( $KPI, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $KPI );

    # check needed objects
    for my $Object (qw(DBObject ConfigObject LogObject MainObject EncodeObject)) {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }

    # create additional objects
    $Self->{CacheObject} = Kernel::System::Cache->new( %{$Self} );
    $Self->{ValidObject} = Kernel::System::Valid->new( %{$Self} );
    $Self->{YAMLObject}  = Kernel::System::YAML->new( %{$Self} );

    # get the cache TTL (in seconds)
    # TODO set config setting
    $Self->{CacheTTL} = int( $Self->{ConfigObject}->Get('CRKPIs::CacheTTL') || 3600 );

    # set lower if database is case sensitive
    $Self->{Lower} = '';
    if ( $Self->{DBObject}->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    return $Self;
}

=item KPIAdd()

add a new KPI

    my $ID = $KPIObject->KPIAdd(
        Name          => 'New KPI',
        Comments      => 'A description of the new KPI',
        Object        => 'Generic',                            # Ticket, or FAQ or ITSMCI or ITSMChange, etc.
        Config        => $ConfigHashRef,
        ValidID       => 1,
        GroupIDs      => [ 1, 2, 3],
        UserID        => 123,
    );
=cut

sub KPIAdd {
    my ( $Self, %Param ) = @_;

    # check needed parameters
    for my $Needed (qw(Name Config Object ValidID GroupIDs UserID)) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check GroupID
    if ( !IsArrayRefWithData( $Param{GroupIDs} ) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "KPI GroupIDs should be a non empty array reference!",
        );
        return;
    }

    # check config
    if ( !IsHashRefWithData( $Param{Config} ) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "KPI Config should be a non empty hash reference!",
        );
        return;
    }

    # check if Name already exists
    return if !$Self->{DBObject}->Prepare(
        SQL   => "
            SELECT id FROM cr_kpi
            WHERE $Self->{Lower}(name) = $Self->{Lower}(?)",
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    my $NameExists;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $NameExists = 1;
    }

    if ($NameExists) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "The name $Param{Name} already exists for a KPI!"
        );
        return;
    }

    # dump config as string
    my $Config = $Self->{YAMLObject}->Dump( Data => $Param{Config} );

    # Make sure the resulting string has the UTF-8 flag. YAML only sets it if
    #   part of the data already had it.
    utf8::upgrade($Config);

    # create the kpi entry in the DB
    return if !$Self->{DBObject}->Do(
        SQL => '
            INSERT INTO cr_kpi (name, comments, object, config, valid_id, create_time, create_by,
                change_time, change_by)
            VALUES (?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name},  \$Param{Comments}, \$Param{Object}, \$Config,
            \$Param{ValidID}, \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get new kpi id
    return if !$Self->{DBObject}->Prepare(
        SQL   => 'SELECT id FROM cr_kpi WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $ID = $Row[0];
    }
    return if !$ID;

    # insert new data
    for my $GroupID ( @{ $Param{GroupIDs} } ) {
        return if !$Self->{DBObject}->Do(
            SQL => '
                INSERT INTO cr_kpi_group (group_id, kpi_id)
                VALUES (?, ?)',
            Bind => [ \$GroupID, \$ID ],
        );
    }

    # delete cache
    $Self->{CacheObject}->CleanUp(
        Type => 'CRKPI',
    );

    return $ID;
}

=item KPIDelete()

delete a KPI

returns 1 if successful or undef otherwise

    my $Success = $KPIObject->KPIDelete(
        ID      => 123,
        UserID  => 123,
    );

=cut

sub KPIDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(ID UserID)) {
        if ( !$Param{$Key} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message => "Need $Key!"
            );
            return;
        }
    }

    # check if exists
    my $KPI = $Self->KPIGet(
        ID => $Param{ID},
    );

    return if !IsHashRefWithData($KPI);

    # delete KPI group ids
    return if !$Self->{DBObject}->Do(
        SQL  => '
            DELETE FROM cr_kpi_group
            WHERE kpi_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete KPI
    return if !$Self->{DBObject}->Do(
        SQL  => '
            DELETE FROM cr_kpi
            WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete cache
    $Self->{CacheObject}->CleanUp(
        Type => 'CRKPI',
    );

    return 1;
}

=item KPIGet()

get KPI details

    my $KPI = $KPIObject->KPIGet(
        ID => 34,
    );

    my $KPI = $KPIObject->KPIGet(
        Name => 'KPI Name',
    );

Returns:

    %KPI = {
        ID                  => '34',
        Name                => 'KPI Name',
        Comments            => 'This is a default KPI',
        Object              => 'Generic'                             # Ticket, or FAQ or ITSMCI or ITSMChange, etc.
        Config              => $ConfigHashRef,
        GroupIDs            => [1, 2, 3],
        ValidID             => '1',
        CreateTime          => '2011-12-01 08:01:23',
        CreateBy            => '12',
        ChangeTime          => '2011-12-02 10:45:01',
        ChangeBy            => '8',
    };

=cut

sub KPIGet {
    my ( $Self, %Param ) = @_;

    # either ID or Name must be passed
    if ( !$Param{ID} && !$Param{Name} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need ID or Name!',
        );
        return;
    }

    # check that not both ID and Name are given
    if ( $Param{ID} && $Param{Name} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need either ID or Name - not both!',
        );
        return;
    }

    # check cache
    my $CacheKey;
    if ( $Param{ID} ) {
        $CacheKey = 'KPIGet::ID::' . $Param{ID};
    }
    else {
        $CacheKey = 'KPIGet::Name::' . $Param{Name};

    }
    my $Cache = $Self->{CacheObject}->Get(
        Type => 'CRKPI',
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    # sql
    if ( $Param{ID} ) {
        return if !$Self->{DBObject}->Prepare(
            SQL =>'
                SELECT id, name, comments,object, config, valid_id, create_time, create_by,
                    change_time, change_by
                FROM cr_kpi
                WHERE id = ?',
            Bind => [ \$Param{ID} ],
        );
    }
    else {
        return if !$Self->{DBObject}->Prepare(
            SQL =>'
                SELECT id, name, comments, object, config, valid_id, create_time, create_by,
                    change_time, change_by
                FROM cr_kpi
                WHERE name = ?',
            Bind => [ \$Param{Name} ],
        );
    }

    # fetch the result
    my %KPI;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        my $Config = $Self->{YAMLObject}->Load( Data => $Row[4] ) || {};

        $KPI{ID}         = $Row[0];
        $KPI{Name}       = $Row[1];
        $KPI{Comments}   = $Row[2];
        $KPI{Object}     = $Row[3];
        $KPI{Config}     = $Config;
        $KPI{ValidID}    = $Row[5];
        $KPI{CreateTime} = $Row[6];
        $KPI{CreateBy}   = $Row[7];
        $KPI{ChangeTime} = $Row[8];
        $KPI{ChangeBy}   = $Row[9];
    }

    if ( !$KPI{ID} ) {
        if ( $Param{ID} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "KPI ID:'$Param{ID}' not found!",
            );
            return;
        }
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "KPI Name:'$Param{Name}' not found!",
        );
        return;
    }

    # ask the database for the group ids
    return if !$Self->{DBObject}->Prepare(
        SQL => 'SELECT group_id
                FROM cr_kpi_group
                WHERE kpi_id = ?
                ORDER BY group_id',
        Bind => [ \$KPI{ID} ],
    );

    # fetch the result
    my @GroupIDs;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        push( @GroupIDs, $Row[0] );
    }

    $KPI{GroupIDs} = \@GroupIDs;

    # set cache
    $Self->{CacheObject}->Set(
        Type  => 'CRKPI',
        Key   => $CacheKey,
        Value => \%KPI,
        TTL   => $Self->{CacheTTL},
    );

    return \%KPI;
}

=item KPIUpdate()

update KPI details

    my $Success = $KPIObject->KPIAdd(
        Name          => 'New KPI',
        Comments      => 'A description of the new KPI',
        Object        => 'Generic'                             # Ticket, or FAQ or ITSMCI or ITSMChange, etc.
        Config        => $ConfigHashRef,
        ValidID       => 1,
        GroupIDs      => [ 1, 2, 3],
        UserID        => 123,
    );

Returns:

    $Success = 1;                                             # or undef
=cut

sub KPIUpdate {
    my ( $Self, %Param ) = @_;

    # check needed parameters
    for my $Needed (qw(Name Config Object ValidID GroupIDs UserID)) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check GroupID
    if ( !IsArrayRefWithData( $Param{GroupIDs} ) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "KPI GroupIDs should be a non empty array reference!",
        );
        return;
    }

    # check config
    if ( !IsHashRefWithData( $Param{Config} ) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "KPI Config should be a non empty hash reference!",
        );
        return;
    }

    # check if Name already exists
    return if !$Self->{DBObject}->Prepare(
        SQL   => "
            SELECT id FROM cr_kpi
            WHERE $Self->{Lower}(name) = $Self->{Lower}(?)
                AND id != ?",
        Bind  => [ \$Param{Name}, \$Param{ID} ],
        Limit => 1,
    );

    my $NameExists;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $NameExists = 1;
    }

    if ($NameExists) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "The name $Param{Name} already exists for a KPI!"
        );
        return;
    }

    # dump config as string
    my $Config = $Self->{YAMLObject}->Dump( Data => $Param{Config} );

    # Make sure the resulting string has the UTF-8 flag. YAML only sets it if
    #   part of the data already had it.
    utf8::upgrade($Config);

    # update the kpi entry in the DB
    return if !$Self->{DBObject}->Do(
        SQL => '
            UPDATE cr_kpi
            SET  name = ?, comments = ?, object = ?, config = ?, valid_id = ?,
                change_time = current_timestamp, change_by = ?',
        Bind => [
            \$Param{Name},  \$Param{Comments}, \$Param{Object}, \$Config, \$Param{ValidID},
            \$Param{UserID},
        ],
    );

    # delete KPI group ids
    return if !$Self->{DBObject}->Do(
        SQL  => '
            DELETE FROM cr_kpi_group
            WHERE kpi_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # insert new data
    for my $GroupID ( @{ $Param{GroupIDs} } ) {
        return if !$Self->{DBObject}->Do(
            SQL => '
                INSERT INTO cr_kpi_group (group_id, kpi_id)
                VALUES (?, ?)',
            Bind => [ \$GroupID, \$Param{ID} ],
        );
    }

    # delete cache
    $Self->{CacheObject}->CleanUp(
        Type => 'CRKPI',
    );

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

