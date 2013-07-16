# --
# Kernel/Modules/AdminCRKPI.pm - provides a KPIs view for admins
# Copyright (C) 2001-2013 Carlos Rodríguez
# --
# Based in OTRS file Kernel/Modules/AdminDynamicField.pm
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminCRKPI;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::System::Valid;
use Kernel::System::CheckItem;
use Kernel::System::CRKPI;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    for (qw(ParamObject LayoutObject LogObject ConfigObject)) {
        if ( !$Self->{$_} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $_!" );
        }
    }

    # create additional objects
    $Self->{ValidObject} = Kernel::System::Valid->new( %{$Self} );

    $Self->{KPIObject} = Kernel::System::CRKPI->new( %{$Self} );

    # get configured object types
    $Self->{ObjectTypeConfig} = $Self->{ConfigObject}->Get('CRDashboardKPIs::ObjectType') || {};


    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    if ( $Self->{Subaction} eq 'KPIDelete' ) {

        # challenge token check for write action
        $Self->{LayoutObject}->ChallengeTokenCheck();

        return $Self->_KPIDelete(
            %Param,
        );
    }

    return $Self->_ShowOverview(
        %Param,
        Action => 'Overview',
    );
}

# AJAX subaction
sub _KPIDelete {
    my ( $Self, %Param ) = @_;

    my $Confirmed = $Self->{ParamObject}->GetParam( Param => 'Confirmed' );

    if ( !$Confirmed ) {
        $Self->{'LogObject'}->Log(
            'Priority' => 'error',
            'Message'  => "Need 'Confirmed'!",
        );
        return;
    }

    my $ID = $Self->{ParamObject}->GetParam( Param => 'ID' );

    my $KPIData = $Self->{KPIObject}->KPIGet(
        ID => $ID,
    );

    if ( !IsHashRefWithData($KPIData) ) {
        $Self->{'LogObject'}->Log(
            'Priority' => 'error',
            'Message'  => "Could not find KPI $ID!",
        );
        return;
    }

    my $Success = $Self->{KPIObject}->KPIDelete(
        ID     => $ID,
        UserID => $Self->{UserID},
    );

    return $Self->{LayoutObject}->Attachment(
        ContentType => 'text/html',
        Content     => $Success,
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _ShowOverview {
    my ( $Self, %Param ) = @_;

    my $Output = $Self->{LayoutObject}->Header();
    $Output .= $Self->{LayoutObject}->NavigationBar();

    # call all needed dtl blocks
    $Self->{LayoutObject}->Block(
        Name => 'Main',
        Data => \%Param,
    );

    my %ObjectTypes;
    my %ObjectTypeDialogs;

    if ( !IsHashRefWithData( $Self->{ObjectTypeConfig} ) ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Objects configuration is not valid",
        );
    }

    # get the object types (backends) and its config dialogs
    OBJECTTYPE:
    for my $ObjectType ( sort keys %{ $Self->{ObjectTypeConfig} } ) {
        next OBJECTTYPE if !$Self->{ObjectTypeConfig}->{$ObjectType};

        # add the object type to the list
        $ObjectTypes{$ObjectType} = $Self->{ObjectTypeConfig}->{$ObjectType}->{DisplayName};

        # get the config dialog
        $ObjectTypeDialogs{$ObjectType} =
            $Self->{ObjectTypeConfig}->{$ObjectType}->{ConfigDialog};
    }

    # create the Add KPI select
    my $AddKPIStrg = $Self->{LayoutObject}->BuildSelection(
        Data          => \%ObjectTypes,
        Name          => 'ObjectType',
        PossibleNone  => 1,
        Translation   => 1,
        Sort          => 'AlphanumericValue',
        SelectedValue => '-',
        Class         => 'W75pc',
    );

    # call ActionAddKPI block
    $Self->{LayoutObject}->Block(
        Name => 'ActionAddKPI',
        Data => {
            %Param,
            AddKPIStrg => $AddKPIStrg,
        },
    );

    # parse the object type dialogs as JSON structure
    my $ObjectTypeDialogsConfig = $Self->{LayoutObject}->JSONEncode(
        Data => \%ObjectTypeDialogs,
    );

    # set JS configuration
    $Self->{LayoutObject}->Block(
        Name => 'ConfigSet',
        Data => {
            ObjectTypeDialogsConfig => $ObjectTypeDialogsConfig,
        },
    );

    # call hint block
    $Self->{LayoutObject}->Block(
        Name => 'Hint',
        Data => \%Param,
    );

    # get KPIs list
    my $KPIList = $Self->{KPIObject}->KPIList(
        Valid => 0,
    );

    # print the list of KPIs
    $Self->_KPIListShow(
        KPIs  => $KPIList,
        Total => scalar @{$KPIList},
    );

    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminCRKPI',
        Data         => {
            %Param,
        },
    );

    $Output .= $Self->{LayoutObject}->Footer();
    return $Output;
}

sub _KPIListShow {
    my ( $Self, %Param ) = @_;

    # check start option, if higher than KPIs available, set it to the last KPI page
    my $StartHit = $Self->{ParamObject}->GetParam( Param => 'StartHit' ) || 1;

    # get personal page shown count
    my $PageShownPreferencesKey = 'AdminKPIOverviewPageShown';
    my $PageShown               = $Self->{$PageShownPreferencesKey} || 35;
    my $Group                   = 'KPIOverviewPageShown';

    # get data selection
    my %Data;
    my $Config = $Self->{ConfigObject}->Get('PreferencesGroups');
    if ( $Config && $Config->{$Group} && $Config->{$Group}->{Data} ) {
        %Data = %{ $Config->{$Group}->{Data} };
    }

    # calculate max. shown per page
    if ( $StartHit > $Param{Total} ) {
        my $Pages = int( ( $Param{Total} / $PageShown ) + 0.99999 );
        $StartHit = ( ( $Pages - 1 ) * $PageShown ) + 1;
    }

    # build nav bar
    my $Limit = $Param{Limit} || 20_000;
    my %PageNav = $Self->{LayoutObject}->PageNavBar(
        Limit     => $Limit,
        StartHit  => $StartHit,
        PageShown => $PageShown,
        AllHits   => $Param{Total} || 0,
        Action    => 'Action=' . $Self->{LayoutObject}->{Action},
        Link      => $Param{LinkPage},
        IDPrefix  => $Self->{LayoutObject}->{Action},
    );

    # build shown KPIs per page
    $Param{RequestedURL}    = "Action=$Self->{Action}";
    $Param{Group}           = $Group;
    $Param{PreferencesKey}  = $PageShownPreferencesKey;
    $Param{PageShownString} = $Self->{LayoutObject}->BuildSelection(
        Name        => $PageShownPreferencesKey,
        SelectedID  => $PageShown,
        Translation => 0,
        Data        => \%Data,
    );

    if (%PageNav) {
        $Self->{LayoutObject}->Block(
            Name => 'OverviewNavBarPageNavBar',
            Data => \%PageNav,
        );

        $Self->{LayoutObject}->Block(
            Name => 'ContextSettings',
            Data => { %PageNav, %Param, },
        );
    }

    # check if at least 1 KPI is registered in the system
    if ( $Param{Total} ) {

        # get KPIs details
        my $Counter = 0;

        KPIID:
        for my $KPIID ( @{ $Param{KPIs} } ) {
            $Counter++;
            if ( $Counter >= $StartHit && $Counter < ( $PageShown + $StartHit ) ) {

                my $KPIData = $Self->{KPIObject}->KPIGet(
                    ID => $KPIID,
                );
                next KPIID if !IsHashRefWithData($KPIData);

                # convert ValidID to Validity string
                my $Valid = $Self->{ValidObject}->ValidLookup(
                    ValidID => $KPIData->{ValidID},
                );

                # get the object type display name
                my $ObjectTypeName
                    = $Self->{ObjectTypeConfig}->{ $KPIData->{ObjectType} }->{DisplayName}
                    || $KPIData->{ObjectType};

                # get the KPI backend dialog
                my $ConfigDialog
                    = $Self->{ObjectTypeConfig}->{ $KPIData->{ObjectType} }->{ConfigDialog}
                    || '';

                # print each KPI row
                $Self->{LayoutObject}->Block(
                    Name => 'KPIsRow',
                    Data => {
                        %{$KPIData},
                        Valid          => $Valid,
                        ConfigDialog   => $ConfigDialog,
                        ObjectTypeName => $ObjectTypeName,
                    },
                );

                $Self->{LayoutObject}->Block(
                    Name => 'DeleteLink',
                    Data => {
                        %{$KPIData},
                        Valid          => $Valid,
                        ConfigDialog   => $ConfigDialog,
                        ObjectTypeName => $ObjectTypeName,
                    },
                );
            }
        }
    }

    # otherwise show a no data found message
    else {
        $Self->{LayoutObject}->Block(
            Name => 'NoDataFound',
            Data => \%Param,
        );
    }
    return;
}

1;
