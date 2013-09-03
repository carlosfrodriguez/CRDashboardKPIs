# --
# Kernel/Output/HTML/DashboardCRKPI.pm
# Copyright (C) 2001-2013 Carlos Rodríguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::DashboardCRKPI;

use strict;
use warnings;

use Kernel::System::CRKPI;
use Kernel::System::Group;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed objects
    for my $Object (
        qw(
        Config Name ConfigObject LogObject DBObject LayoutObject ParamObject TicketObject
        QueueObject UserID
        )
        )
    {
        die "Got no $Object!" if ( !$Self->{$Object} );
    }

    $Self->{KPIObject}   = Kernel::System::CRKPI->new(%Param);
    $Self->{GroupObject} = Kernel::System::Group->new(%Param);

    $Self->{PrefKey} = 'UserDashboardPref' . $Self->{Name} . '-Shown';

    $Self->{CacheKey}
        = $Self->{Name} . '-'
        . $Self->{UserID};

    # get configured object types
    $Self->{ObjectTypeConfig} = $Self->{ConfigObject}->Get('CRDashboardKPIs::ObjectType') || {};

    # check backends
    OBJECTTYPE:
    for my $ObjectType (sort keys %{ $Self->{ObjectTypeConfig} } ) {

        my $Backend = $Self->{ObjectTypeConfig}->{$ObjectType}->{DashboardBackend};
        my $Module = 'Kernel::Output::HTML::' . $Backend;

        if (!$Module) {
            $Self->{LogObject}->Log(
                Priority => 'Error',
                Message  => "No DashboardBackend for Object $ObjectType",
            );
            next OBJECTTYPE;
        }
        if ( !$Self->{MainObject}->Require($Module) ) {
            die "Can't load Dashboard KPI Backend $Module";
        }
        $Self->{"DashboardBackend$ObjectType"} = $Module->new(%{$Self});
    }

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    return;
}

sub Config {
    my ( $Self, %Param ) = @_;

    return (
        %{ $Self->{Config} },

        # remember, do not allow to use page cache
        # (it's not working because of internal filter)
        CacheKey => undef,
        CacheTTL => undef,
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get user groups
    my %Groups = $Self->{GroupObject}->GroupMemberList(
        UserID => $Self->{UserID},
        Type   => 'ro',
        Result => 'HASH',
    );

    my $KPIList = $Self->{KPIObject}->KPIList(
        ResultType => 'HASH',
    );

use Data::Dumper;
print STDERR Dumper($KPIList); #TODO Delete Developers Oputput

    my $Counter = 1;

    KPI:
    for my $KPIID ( sort keys %{$KPIList} ) {
        my $KPI = $Self->{KPIObject}->KPIGet(
            ID     => $KPIID,
            UserID => $Self->{UserID},
        );

        # check if user has access to the KPI
        my $Access;
        GROUPID:
        for my $GroupID ( @{ $KPI->{GroupIDs} } ) {
            if ( $Groups{$GroupID} ) {
                $Access = 1;
                last GROUPID;
            }
        }
        next KPI if !$Access;

        # get KPI value from backend
        my $Response = $Self->{"DashboardBackend$KPI->{ObjectType}"}->Run(KPI => $KPI);
        if ( !$Response->{Success} ) {
            $Self->{LogObject}->Log(
                Priority => 'Error',
                Message  => $Response->{Error} || 'Unknown Error!',
            );
        }

        my $Value = $Response->{Value} || 0;

        # print KPI in the dashboard widget
        $Self->{LayoutObject}->Block(
            Name => 'KPI',
            Data => {
                ElementID => "Gage$Counter" ,
                Value     => $Value,
                %{$KPI},
            },
        );
        $Counter ++;
    }

   my $Content = $Self->{LayoutObject}->Output(
        TemplateFile => 'AgentDashboardKPI',
        Data         => {
            %{ $Self->{Config} },
            Name => $Self->{Name},
        },
    );

#    # cache result
#    if ( $Self->{Config}->{CacheTTLLocal} ) {
#        $Self->{CacheObject}->Set(
#            Type  => 'DashboardQueueOverview',
#            Key   => $CacheKey,
#            Value => $Content || '',
#            TTL   => 2 * 60,
#        );
#    }

    return $Content;
}

1;
