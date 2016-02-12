package Koha::Plugin::Edu::FloridaTech::EvansLibrary::CopyPermissions;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Auth;

## Here we set our plugin version
our $VERSION = 1.00;

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Copy Permissions from Circ Account to Workstudy',
    author          => 'Thomas J Misilo',
    description     => 'Copies permissions from the circ account to specified workstudy account',
    date_authored   => '2016-01-19',
    date_updated    => '2016-01-19',
    minimum_version => '3.18',
    maximum_version => undef,
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $next_step = $cgi->param('next_step');

    if ( $next_step eq '2' ) {
        $self->step2();
    } elsif ( $next_step eq '3' ) {
        $self->step3();
    } else {
        $self->step1();
    }
}

## These are helper functions that are specific to this plugin
## You can manage the control flow of your plugin any
## way you wish, but I find this is a good approach
sub step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template( { file => 'step1.tt' } );

    print $cgi->header();
    print $template->output();
}

sub step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $dbh = C4::Context->dbh;

    my $patron = $cgi->param("cardnumber");

    my $query = "
SELECT surname,firstname,cardnumber, categorycode, branchcode, b.borrowernumber, 
IF(flags MOD 2,'Set','') AS SuperLib,
IF(MOD(flags DIV 2,2),'All parameters',GROUP_CONCAT(IF(u_p.module_bit=1,p.code,'') SEPARATOR ' ' ) ) AS CircPermissions, 
IF(MOD(flags DIV 4,2),'Set','') AS 'ViewStaffInterface',
IF(MOD(flags DIV 8,2),'All parameters' ,GROUP_CONCAT(IF(u_p.module_bit=3,p.code,'') SEPARATOR ' ' )  ) AS ManParams,
IF(MOD(flags DIV 16,2),'Set','') AS 'AddModifyPatrons',
IF(MOD(flags DIV 32,2),'Set','') AS 'ModifyPermissions',
IF(MOD(flags DIV 64,2),'All parameters' ,GROUP_CONCAT(IF(u_p.module_bit=6,p.code,'') SEPARATOR ' ' )  ) AS ReservePermissions,
IF(MOD(flags DIV 128,2),'Set','') AS BorrowBooks,
IF(MOD(flags DIV 512,2),'All parameters' ,GROUP_CONCAT(IF(u_p.module_bit=9,p.code,'') SEPARATOR ' ' )  ) AS EditCatalogue,
IF(MOD(flags DIV 1024,2),'All parameters' ,GROUP_CONCAT(IF(u_p.module_bit=10,p.code,'') SEPARATOR ' ' )  ) AS UpdateCharges,
IF(MOD(flags DIV 2048,2),'All parameters' ,GROUP_CONCAT(IF(u_p.module_bit=11,p.code,'') SEPARATOR ' ' )  ) AS Acquisition,
IF(MOD(flags DIV 4096,2),'Set','') AS Management,
IF(MOD(flags DIV 8192,2),'All parameters' ,GROUP_CONCAT(IF(u_p.module_bit=13,p.code,'') SEPARATOR ' ' )  ) AS Tools,
IF(MOD(flags DIV 16384,2),'Set','') AS EditAuthories,
IF(MOD(flags DIV 32768,2),'All parameters' ,GROUP_CONCAT(IF(u_p.module_bit=15,p.code,'') SEPARATOR ' ' )  ) AS Series,
IF(MOD(flags DIV 65536,2),'All parameters' ,GROUP_CONCAT(IF(u_p.module_bit=16,p.code,'') SEPARATOR ' ' )  ) AS Reports,
IF(MOD(flags DIV 131072,2),'Set','') AS StaffAccess,
IF(MOD(flags DIV 262144,2),'All parameters' ,GROUP_CONCAT(IF(u_p.module_bit=18,p.code,'') SEPARATOR ' ' )  ) AS CourseReserves,
IF(MOD(flags DIV 524288,2),'All parameters' ,GROUP_CONCAT(IF(u_p.module_bit=19,p.code,'') SEPARATOR ' ' )  ) AS Plugins
FROM borrowers b
LEFT JOIN user_permissions  u_p ON b.borrowernumber=u_p.borrowernumber
LEFT JOIN permissions p ON u_p.code=p.code
WHERE b.cardnumber = ? AND ( flags>0  OR u_p.module_bit>0 )
GROUP BY b.borrowernumber
ORDER BY categorycode,branchcode,surname,firstname ASC
    ";

    my $sth = $dbh->prepare($query);
    $sth->execute($patron);
    my $record = $sth->fetchrow_hashref();

my $query2 = "
SELECT surname,firstname,cardnumber, categorycode, branchcode, borrowernumber
FROM borrowers b
WHERE b.cardnumber = ?
";

    my $sth2 = $dbh->prepare($query2);
    $sth2->execute($patron);
    my $patrondata =  $sth2->fetchrow_hashref();


    my $template = $self->get_template( { file => "step2.tt" } );

    $template->param( record => $record );
    $template->param( patron => $patrondata );


    print $cgi->header();
    print $template->output();
}

sub step3 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $dbh = C4::Context->dbh;

    my $borrowernumber = $cgi->param("borrowernumber");
    my $sourcenumber = 109355;

#    my $r = $dbh->do( 'DELETE FROM user_permissions WHERE borrowernumber = ?', {}, $borrowernumber );
    # Copy Flag Value from Source to Target
    my $r = $dbh->do( 'UPDATE borrowers AS target LEFT JOIN borrowers AS source ON source.borrowernumber=? SET target.flags=source.flags WHERE target.borrowernumber=?', {}, $sourcenumber, $borrowernumber);

    # Delete existing permissions
    my $r1 = $dbh->do( 'DELETE FROM user_permissions WHERE borrowernumber=?', {}, $borrowernumber);

    my $r2 = $dbh->do( 'INSERT INTO user_permissions (SELECT ?, module_bit, code FROM user_permissions WHERE borrowernumber=?)', {} , $borrowernumber, $sourcenumber);

    my $template = $self->get_template( { file => 'step3.tt' } );
    $template->param( record_deleted => $r );

    print $cgi->header();
    print $template->output();
}

1;
