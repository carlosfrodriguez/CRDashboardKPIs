# --
# Kernel/Output/HTML/DashboardCRKPIGeneric.pm
# Copyright (C) 2001-2013 Carlos Rodríguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::DashboardCRKPIGeneric;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $KPIConfig = $Param{KPI}->{Config};

    return $Self->_ValidateSQL(%{$KPIConfig});
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


1;
