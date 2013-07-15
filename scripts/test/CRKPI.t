# --
# CRKPI.t - KPI tests
# Copyright (C) 2001-2013 Carlos Rodríguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;
use vars (qw($Self));

use Kernel::System::CRKPI;
use Kernel::System::UnitTest::Helper;

my $HelperObject = Kernel::System::UnitTest::Helper->new(
    %$Self,
    UnitTestObject => $Self,
);

my $RandomID = $HelperObject->GetRandomID();

my $KPIObject = Kernel::System::CRKPI->new( %{$Self} );

# set $UserId
my $UserID = 1;

my @AddedKPIs;

# KPIAdd Tests
my @Tests = (
    {
        Name    => 'Empty Params',
        Config  => {},
        Success => 0,
    },
    {
        Name    => 'Missing Name',
        Config  => {
            Name          => undef,
            Comments      => 'A description of the new KPI',
            Object        => 'Generic',
            Config        => {
                Test => 1,
            },
            ValidID       => 1,
            GroupIDs      => [ 1, 2, 3],
            UserID        => $UserID,
        },
        Success => 0,
    },
    {
        Name    => 'Missing Object',
        Config  => {
            Name          => 'New KPI',
            Comments      => 'A description of the new KPI',
            Object        => undef,
            Config        => {
                Test => 1,
            },
            ValidID       => 1,
            GroupIDs      => [ 1, 2, 3],
            UserID        => $UserID,
        },
        Success => 0,
    },
    {
        Name    => 'Missing Config',
        Config  => {
            Name          => 'New KPI',
            Comments      => 'A description of the new KPI',
            Object        => 'Generic',
            Config        => undef,
            ValidID       => 1,
            GroupIDs      => [ 1, 2, 3],
            UserID        => $UserID,
        },
        Success => 0,
    },
    {
        Name    => 'Missing ValidID',
        Config  => {
            Name          => 'New KPI',
            Comments      => 'A description of the new KPI',
            Object        => 'Generic',
            Config        => {
                Test => 1,
            },
            ValidID       => undef,
            GroupIDs      => [ 1, 2, 3],
            UserID        => $UserID,
        },
        Success => 0,
    },
    {
        Name    => 'Missing ValidID',
        Config  => {
            Name          => 'New KPI',
            Comments      => 'A description of the new KPI',
            Object        => 'Generic',
            Config        => {
                Test => 1,
            },
            ValidID       => 1,
            GroupIDs      => undef,
            UserID        => $UserID,
        },
        Success => 0,
    },
    {
        Name    => 'Missing UserID',
        Config  => {
            Name          => 'New KPI',
            Comments      => 'A description of the new KPI',
            Object        => 'Generic',
            Config        => {
                Test => 1,
            },
            ValidID       => 1,
            GroupIDs      => [ 1, 2, 3],
            UserID        => undef,
        },
        Success => 0,
    },
    {
        Name    => 'Wrong Config Format',
        Config  => {
            Name          => 'New KPI',
            Comments      => 'A description of the new KPI',
            Object        => 'Generic',
            Config        => 'Test',
            ValidID       => 1,
            GroupIDs      => [ 1, 2, 3],
            UserID        => $UserID,
        },
        Success => 0,
    },
    {
        Name    => 'Empty Config',
        Config  => {
            Name          => 'New KPI',
            Comments      => 'A description of the new KPI',
            Object        => 'Generic',
            Config        => {},
            ValidID       => 1,
            GroupIDs      => [ 1, 2, 3],
            UserID        => $UserID,
        },
        Success => 0,
    },
    {
        Name    => 'Wrong GroupIDs Format',
        Config  => {
            Name          => 'New KPI',
            Comments      => 'A description of the new KPI',
            Object        => 'Generic',
            Config        => {
                Test => 1,
            },
            ValidID       => 1,
            GroupIDs      => 1,
            UserID        => $UserID,
        },
        Success => 0,
    },
    {
        Name    => 'Empty GroupIDs',
        Config  => {
            Name          => 'New KPI',
            Comments      => 'A description of the new KPI',
            Object        => 'Generic',
            Config        => {
                Test => 1,
            },
            ValidID       => 1,
            GroupIDs      => [],
            UserID        => $UserID,
        },
        Success => 0,
    },
    {
        Name    => 'Correct KPIAdd()',
        Config  => {
            Name          => 'New KPI',
            Comments      => 'A description of the new KPI',
            Object        => 'Generic',
            Config        => {
                Test => 1,
            },
            ValidID       => 1,
            GroupIDs      => [1,2,3],
            UserID        => $UserID,
        },
        Success => 1,
    },
    {
        Name    => 'Duplicated name',
        Config  => {
            Name          => 'New KPI',
            Comments      => 'A description of the new KPI',
            Object        => 'Generic',
            Config        => {
                Test => 1,
            },
            ValidID       => 1,
            GroupIDs      => [1,2,3],
            UserID        => $UserID,
        },
        Success => 0,
    },
    {
        Name    => 'Correct with UTF8',
        Config  => {
            Name          => 'New KPI ÁÉáéóäëñßカスタマПфия',
            Comments      => 'A description of the new KPI ÁÉáéóäëñßカスタマПфия',
            Object        => 'Generic',
            Config        => {
                Test => 'ÁÉáéóäëñßカスタマПфия',
            },
            ValidID       => 1,
            GroupIDs      => [1,2,3],
            UserID        => $UserID,
        },
        Success => 1,
    },
);

for my $Test (@Tests) {

    my $KPIID = $KPIObject->KPIAdd( %{ $Test->{Config} } );

    if ($KPIID) {
        push @AddedKPIs, $KPIID;
    }

    if ( $Test->{Success} ) {
        $Self->IsNot(
            $KPIID,
            undef,
            "$Test->{Name} KPIAdd() | should not be undef",
        );

        # also do success tests from KPIGet() to save time and effort
        my $KPI = $KPIObject->KPIGet( ID => $KPIID );

        $Self->Is(
            $KPI->{ID},
            $KPIID,
            "$Test->{Name} KPIGet() after KPIAdd() | ID"
        );

        # remove the attributes for easy compare
        delete $KPI->{ID};
        delete $KPI->{CreateTime};
        delete $KPI->{CreateBy};
        delete $KPI->{ChangeTime};
        delete $KPI->{ChangeBy};

        # add UserID for easy compare
        $KPI->{UserID} = $UserID;

        $Self->IsDeeply(
            $KPI,
            $Test->{Config},
            "$Test->{Name} KPIGet() after KPIAdd() | results"
        );
    }
    else {
        $Self->Is(
            $KPIID,
            undef,
            "$Test->{Name} KPIADD() | should be undef",
        );
    }
}

# KPIDelete tests (Other delete tests are also done in system cleanup)

# create a new KPI to delete
my $KPIIDToDelete = $KPIObject->KPIAdd(
    Name          => 'KPI to delete',
    Comments      => 'A description of the new KPI',
    Object        => 'Generic',
    Config        => {
        Test => 1
    },
    ValidID       => 1,
    GroupIDs      => [ 1, 2, 3],
    UserID        => $UserID,
);

# sanity test
$Self->IsNot(
    $KPIIDToDelete,
    undef,
    'KPIADD() for KPIDelete() tests | should not be undef',
);

@Tests = (
    {
        Name    => 'Empty Params',
        Config  => {},
        Success => 0,
    },
    {
        Name    => 'Missing ID',
        Config  => {
            ID     => undef,
            UserID => $UserID,
        },
        Success => 0,
    },
    {
        Name    => 'Missing UserID',
        Config  => {
            ID     => $KPIIDToDelete,
            UserID => undef,
        },
        Success => 0,
    },
    {
        Name    => 'Correct KPI to delete',
        Config  => {
            ID     => $KPIIDToDelete,
            UserID => $UserID,
        },
        Success => 1,
    },
    {
        Name    => 'Already deleted KPI',
        Config  => {
            ID     => $KPIIDToDelete,
            UserID => $UserID,
        },
        Success => 0,
    },
);

for my $Test (@Tests) {
    my $Success = $KPIObject->KPIDelete( %{ $Test->{Config} } );

    if ( $Test->{Success} ) {
        $Self->True(
            $Success,
            "$Test->{Name} KPIDelete() | With True",
        );
    }
    else {
        $Self->False(
            $Success,
            "$Test->{Name} KPIDelete() | With False",
        );
    }
}

# KPIGet() tests (other tests has been done in other parts of this file)

# create a new KPI to Get
my %KPIToGet = (
    Name          => 'KPI to Get',
    Comments      => 'A description of the new KPI',
    Object        => 'Generic',
    Config        => {
        Test => 1
    },
    ValidID       => 1,
    GroupIDs      => [ 1, 2, 3],
    UserID        => $UserID,
);
my $KPIIDToGet = $KPIObject->KPIAdd(%KPIToGet);

# sanity test
$Self->IsNot(
    $KPIIDToGet,
    undef,
    'KPIADD() for KPIGet() tests | should not be undef',
);


# Add the ID
$KPIToGet{ID} = $KPIIDToGet;
push @AddedKPIs, $KPIIDToGet;

@Tests = (
    {
        Name    => 'Empty Params',
        Config  => {},
        Success => 0,
    },
    {
        Name    => 'Missing ID',
        Config  => {
            ID => undef,
        },
        Success => 0,
    },
    {
        Name    => 'Missing Name',
        Config  => {
            Name => undef,
        },
        Success => 0,
    },
    {
        Name    => 'Wrong ID',
        Config  => {
            ID => -1,
        },
        Success => 0,
    },
    {
        Name    => 'Wrong Name',
        Config  => {
            Name => 'NotExisitng' . $RandomID,
        },
        Success => 0,
    },
    {
        Name    => 'Both ID and Name',
        Config  => {
            ID   => $KPIToGet{ID},
            Name => $KPIToGet{Name},
        },
        Success => 0,
    },
    {
        Name    => 'Correct ID',
        Config  => {
            ID   => $KPIToGet{ID},
        },
        Success => 1,
    },
    {
        Name    => 'Correct Name',
        Config  => {
            Name => $KPIToGet{Name},
        },
        Success => 1,
    },
);

for my $Test (@Tests) {
    my $KPI = $KPIObject->KPIGet( %{ $Test->{Config} } );

    if ( $Test->{Success} ) {

        my $CacheKey;
        # check the cache
        if ( $Test->{Config}->{ID} ) {
            $CacheKey = 'KPIGet::ID::' . $Test->{Config}->{ID};
        }
        else {
            $CacheKey = 'KPIGet::Name::' . $Test->{Config}->{Name};

        }
        my $Cache = $KPIObject->{CacheObject}->Get(
            Type => 'CRKPI',
            Key  => $CacheKey,
        );

        $Self->IsDeeply(
            $KPI,
            $Cache,
            "$Test->{Name} KPIGet() cache |"
        );

        # remove the attributes for easy compare
        delete $KPI->{CreateTime};
        delete $KPI->{CreateBy};
        delete $KPI->{ChangeTime};
        delete $KPI->{ChangeBy};

        $KPI->{UserID} = $UserID;

        $Self->IsDeeply(
            $KPI,
            \%KPIToGet,
             "$Test->{Name} KPIGet() |",
        );
    }
    else {
        $Self->Is(
            $KPI,
            undef,
            "$Test->{Name} KPIGet() | should be undef",
        );
    }
}

# System Cleanup
for my $KPIID (@AddedKPIs) {
    my $Success = $KPIObject->KPIDelete(
        ID     => $KPIID,
        UserID => $UserID,
    );

    $Self->True(
        $Success,
        "System Cleanup | Deleted KPI with ID: '$KPIID'",
    );
}

1;