# --
# Kernel/Modules/AdminCRKPIGeneric.pm - provides a KPI Generic config view for admins
# Copyright (C) 2001-2013 Carlos Rodríguez
# --
# Based in OTRS file Kernel/Modules/AdminDynamicFieldText.pm
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminCRKPIGeneric;

use strict;
use warnings;

use Kernel::System::CRKPI;

use Kernel::System::Group;
use Kernel::System::CheckItem;
use Kernel::System::Valid;
use Kernel::System::VariableCheck qw(:all);

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
    $Self->{GroupObject} = Kernel::System::Group->new( %{$Self} );
    $Self->{ValidObject} = Kernel::System::Valid->new( %{$Self} );

    $Self->{KPIObject} = Kernel::System::CRKPI->new( %{$Self} );

    # get configured object types
    $Self->{ObjectTypeConfig} = $Self->{ConfigObject}->Get('CRDashboardKPIs::ObjectType');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    if ( $Self->{Subaction} eq 'Add' ) {
        return $Self->_Add(
            %Param,
        );
    }
    elsif ( $Self->{Subaction} eq 'AddAction' ) {

        # challenge token check for write action
        $Self->{LayoutObject}->ChallengeTokenCheck();

        return $Self->_AddAction(
            %Param,
        );
    }
    if ( $Self->{Subaction} eq 'Change' ) {
        return $Self->_Change(
            %Param,
        );
    }
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {

        # challenge token check for write action
        $Self->{LayoutObject}->ChallengeTokenCheck();

        return $Self->_ChangeAction(
            %Param,
        );
    }
    elsif ( $Self->{Subaction} eq 'Test' ) {

        return $Self->_Test(
            %Param,
        );

    }
    return $Self->{LayoutObject}->ErrorScreen(
        Message => "Undefined subaction.",
    );
}

sub _Add {
    my ( $Self, %Param ) = @_;

    my %GetParam;
    for my $Needed (qw(ObjectType)) {
        $GetParam{$Needed} = $Self->{ParamObject}->GetParam( Param => $Needed );
        if ( !$Needed ) {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Need $Needed",
            );
        }
    }

    # get the object type and field type display name
    my $ObjectTypeName = $Self->{ObjectTypeConfig}->{ $GetParam{ObjectType} }->{DisplayName} || '';

    # set KPI default values
    $GetParam{Title} = 'New';
    $GetParam{Min} = 0;
    $GetParam{Max} = 100;

    return $Self->_ShowScreen(
        %Param,
        %GetParam,
        Mode           => 'Add',
        ObjectTypeName => $ObjectTypeName,
    );
}

sub _AddAction {
    my ( $Self, %Param ) = @_;

    my %Errors;
    my %GetParam;

    for my $Needed (qw(Name Min Max SQLStatement ObjectType)) {
        $GetParam{$Needed} = $Self->{ParamObject}->GetParam( Param => $Needed );
        if ( !$GetParam{$Needed} ) {
            $Errors{ $Needed . 'ServerError' }        = 'ServerError';
            $Errors{ $Needed . 'ServerErrorMessage' } = 'This field is required.';
        }
    }

    my @GroupIDs = $Self->{ParamObject}->GetArray( Param => 'GroupIDs' );
        $GetParam{GroupIDs} =\@GroupIDs;
        if ( !IsArrayRefWithData( $GetParam{GroupIDs} ) ) {
            $Errors{ 'GroupIDsServerError' }        = 'ServerError';
            $Errors{ 'GroupIDsServerErrorMessage' } = 'This field is required.';
        }

    for my $OtherValues (qw(Comments ValidID ObjectTypeName)) {
        $GetParam{$OtherValues} = $Self->{ParamObject}->GetParam( Param => $OtherValues );
    }

    # Validate SQL statement
    my $ValidateResult = $Self->_ValidateSQL( SQLStatement => $GetParam{SQLStatement} );

    if ( !$ValidateResult->{Success} ) {

        # add server error class
        $Errors{SQLStatementServerError}  = 'ServerError';
        $Errors{SQLStatementServerErrorMessage} = $ValidateResult->{Error};
    }

    # uncorrectable errors
    if ( !$GetParam{ValidID} ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Need ValidID",
        );
    }

    if ( $GetParam{Name} ) {

        # check if name is duplicated
        my %KPIsList = %{
            $Self->{KPIObject}->KPIList(
                Valid      => 0,
                ResultType => 'HASH',
                )
        };

        %KPIsList = reverse %KPIsList;

        if ( $KPIsList{ $GetParam{Name} } ) {

            # add server error class
            $Errors{NameServerError}        = 'ServerError';
            $Errors{NameServerErrorMessage} = 'There is another field with the same name.';
        }
    }

    # return to add screen if errors
    if (%Errors) {
        return $Self->_ShowScreen(
            %Param,
            %Errors,
            %GetParam,
            Mode => 'Add',
        );
    }

    # set specific config
    my $KPIConfig = {
        SQLStatement => $GetParam{SQLStatement},
    };

    # add a new KPI to the DB
    my $KPIID = $Self->{KPIObject}->KPIAdd(
        Name          => $GetParam{Name},
        Comments      => $GetParam{Comments},
        ObjectType    => $GetParam{ObjectType},
        Config        => $KPIConfig,
        ValidID       => $GetParam{ValidID},
        GroupIDs      => $GetParam{GroupIDs},
        Min           => $GetParam{Min},
        Max           => $GetParam{Max},
        UserID        => $Self->{UserID},
    );

    if ( !$KPIID ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not create the new KPI",
        );
    }

    return $Self->{LayoutObject}->Redirect(
        OP => "Action=AdminCRKPI",
    );
}

sub _Change {
    my ( $Self, %Param ) = @_;

    my %GetParam;
    for my $Needed (qw(ObjectType)) {
        $GetParam{$Needed} = $Self->{ParamObject}->GetParam( Param => $Needed );
        if ( !$Needed ) {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Need $Needed",
            );
        }
    }

    # get the object type and field type display name
    my $ObjectTypeName = $Self->{ObjectTypeConfig}->{ $GetParam{ObjectType} }->{DisplayName} || '';

    my $KPIID = $Self->{ParamObject}->GetParam( Param => 'ID' );

    if ( !$KPIID ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Need ID",
        );
    }

    # get KPI data
    my $KPIData = $Self->{KPIObject}->KPIGet(
        ID      => $KPIID,
        UserID  => $Self->{UserID},
    );

    # check for valid KPI configuration
    if ( !IsHashRefWithData($KPIData) ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not get data for KPI $KPIID",
        );
    }

    my %Config = ();

    # extract configuration
    if ( IsHashRefWithData( $KPIData->{Config} ) ) {
        %Config = %{ $KPIData->{Config} };
    }

    return $Self->_ShowScreen(
        %Param,
        %GetParam,
        %{ $KPIData },
        %Config,
        Mode           => 'Change',
        ObjectTypeName => $ObjectTypeName,
    );
}

sub _ChangeAction {
    my ( $Self, %Param ) = @_;

    my %Errors;
    my %GetParam;

    for my $Needed (qw(Name Min Max SQLStatement ObjectType)) {
        $GetParam{$Needed} = $Self->{ParamObject}->GetParam( Param => $Needed );
        if ( !$GetParam{$Needed} ) {
            $Errors{ $Needed . 'ServerError' }        = 'ServerError';
            $Errors{ $Needed . 'ServerErrorMessage' } = 'This field is required.';
        }
    }

    my @GroupIDs = $Self->{ParamObject}->GetArray( Param => 'GroupIDs' );
        $GetParam{GroupIDs} =\@GroupIDs;
        if ( !IsArrayRefWithData( $GetParam{GroupIDs} ) ) {
            $Errors{ 'GroupIDsServerError' }        = 'ServerError';
            $Errors{ 'GroupIDsServerErrorMessage' } = 'This field is required.';
        }

    for my $OtherValues (qw(Comments ValidID ObjectTypeName)) {
        $GetParam{$OtherValues} = $Self->{ParamObject}->GetParam( Param => $OtherValues );
    }

    my $KPIID = $Self->{ParamObject}->GetParam( Param => 'ID' );

    # get KPI field data
    my $KPIData = $Self->{KPIObject}->KPIGet(
        ID     => $KPIID,
        UserID => $Self->{UserID}
    );

    # check for valid KPI configuration
    if ( !IsHashRefWithData($KPIData) ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not get data for KPI $KPIID",
        );
    }

    if ( $GetParam{Name} ) {

        # check if name is duplicated
        my %KPIsList = %{
            $Self->{KPIObject}->KPIList(
                Valid      => 0,
                ResultType => 'HASH',
                )
        };

        %KPIsList = reverse %KPIsList;

        if ( $KPIsList{ $GetParam{Name} } && $KPIsList{ $GetParam{Name} } ne $KPIID ) {

            # add server error class
            $Errors{NameServerError}        = 'ServerError';
            $Errors{NameServerErrorMessage} = 'There is another field with the same name.';
        }
    }

    # Validate SQL statement
    my $ValidateResult = $Self->_ValidateSQL( SQLStatement => $GetParam{SQLStatement} );

    if ( !$ValidateResult->{Success} ) {

        # add server error class
        $Errors{SQLStatementServerError}  = 'ServerError';
        $Errors{SQLStatementServerErrorMessage} = $ValidateResult->{Error};
    }

    # uncorrectable errors
    if ( !$GetParam{ValidID} ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Need ValidID",
        );
    }

    # return to change screen if errors
    if (%Errors) {
        return $Self->_ShowScreen(
            %Param,
            %Errors,
            %GetParam,
            ID   => $KPIID,
            Mode => 'Change',
        );
    }

    # set specific config
    my $KPIConfig = {
        SQLStatement => $GetParam{SQLStatement},
    };

    # update KPI data
    my $UpdateSuccess = $Self->{KPIObject}->KPIUpdate(
        ID         => $KPIID,
        Name       => $GetParam{Name},
        Comments   => $GetParam{Comments},
        ObjectType => $GetParam{ObjectType},
        Config     => $KPIConfig,
        ValidID    => $GetParam{ValidID},
        GroupIDs   => $GetParam{GroupIDs},
        Min        => $GetParam{Min},
        Max        => $GetParam{Max},
        UserID     => $Self->{UserID},
    );

    if ( !$UpdateSuccess ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not update the KPI $GetParam{Name}",
        );
    }

    return $Self->{LayoutObject}->Redirect(
        OP => "Action=AdminCRKPI",
    );
}

sub _ShowScreen {
    my ( $Self, %Param ) = @_;

    $Param{DisplayKPIName} = 'New';

    if ( $Param{Mode} eq 'Change' ) {
        $Param{ShowWarning}      = 'ShowWarning';
        $Param{DisplayKPIName} = $Param{Name};
    }

    # header
    my $Output = $Self->{LayoutObject}->Header();
    $Output .= $Self->{LayoutObject}->NavigationBar();

    my %GroupLists = $Self->{GroupObject}->GroupList( Valid => 1 );

    # create the Groups select
    my $GroupStrg = $Self->{LayoutObject}->BuildSelection(
        Data         => \%GroupLists,
        Name         => 'GroupIDs',
        SelectedID   => $Param{GroupIDs},
        PossibleNone => 0,
        Translation  => 1,
        Multiple     => 1,
        Size         => 4,
        Class        => 'W50pc ' . ( $Param{GroupIDsServerError} || '' ),
    );

    my %ValidList = $Self->{ValidObject}->ValidList();

    # create the Validity select
    my $ValidityStrg = $Self->{LayoutObject}->BuildSelection(
        Data         => \%ValidList,
        Name         => 'ValidID',
        SelectedID   => $Param{ValidID} || 1,
        PossibleNone => 0,
        Translation  => 1,
        Class        => 'W50pc',
    );

    # generate output
    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminCRKPIGeneric',
        Data         => {
            %Param,
            GroupStrg    => $GroupStrg,
            ValidityStrg => $ValidityStrg,
        },
    );

    $Output .= $Self->{LayoutObject}->Footer();

    return $Output;
}

sub _ValidateSQL {
    my ( $Self, %Param ) = @_;

    my $SQLStatement = $Param{SQLStatement};

    # only accept Select stements
    if ( $SQLStatement !~ m{\A (?:\s+)? SELECT}msxi ) {
        return {
            Success => 0,
            Error   => 'The SQL Statatement must be a SELECT statement only',
        };
    }

    # should not contain Update or Delete
    if ( $SQLStatement =~ m{\s+ (?:UPDATE|DELETE) \s+ }msxi ) {
        return {
            Success => 0,
            Error   => 'The SQL Statatement should not caontain UPDATE or DELETE',
        };
    }

    # check if SQL statement can be executed
    if ( !$Self->{DBObject}->Prepare(
            SQL   => $SQLStatement,
            Limit => 1,
            )
        )
    {
        return {
            Success => 0,
            Error   => 'The SQL Statatement is invalid',
        };
    }

    my @Data;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        push @Data, $Row[0];
    }

    if ( !IsNumber( $Data[0] ) ) {
        return {
            Success => 0,
            Error   => 'The SQL Statatement result must be a number',
        };
    }

    return {
        Success => 1,
        Value   => $Data[0],
    };
}

sub _Test {
    my ($Self, %Param) = @_;

    my %GetParam;
    $GetParam{SQLStatement} = $Self->{ParamObject}->GetParam( Param => 'SQLStatement' );

    my $ValidateResult;

    if ( !IsStringWithData( $GetParam{SQLStatement} ) ) {
        $ValidateResult = {
            Success => 0,
            Error   => 'The SQL Statement is empty',
        };
    }

    # Validate SQL statement
    $ValidateResult = $Self->_ValidateSQL( SQLStatement => $GetParam{SQLStatement} );

    my $JSON = $Self->{LayoutObject}->JSONEncode(
        Data        => $ValidateResult,
    );

    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
        Content     => $JSON,
        Type        => 'inline',
        NoCache     => 1,
    );
}

1;
