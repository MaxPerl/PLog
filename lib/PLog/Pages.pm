package PLog::Pages;

use 5.006000;
use strict;
use warnings;
use utf8;

use YAML ('LoadFile', 'Load');
use File::Spec;
use Data::Dumper;

require Exporter;

our @ISA = qw(Exporter Gtk3::ApplicationWindow);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use PLog ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

sub new {
	my ($self, $siteobject, $file) = @_;

	my $pageobject = {};
	
	bless $pageobject;
	
	$pageobject->initialize($siteobject, $file);
	
	return $pageobject;
}

sub initialize {
	my ($pageobject, $siteobject, $file) = @_;

	my $yaml_config = extract_file_config($file);
	my $title = $yaml_config->{'title'};
	
	my (undef,$pagedirectory,$pagefile) = File::Spec->splitpath($file);
	
	my $projectdir = $siteobject->{'dir'};
	my $url = File::Spec->abs2rel($pagedirectory, "$projectdir/_source");
	
	# the root site shall be shown as "/"
	$url = "/$url";
	
	$pageobject->{'url'} = "$url";
	$pageobject->{'title'} = "$title";
	$pageobject->{'pagedirectory'} = "$pagedirectory";
	$pageobject->{'pagefile'} = "$file";
	
	# this could be important in latter versions!
	# At the moment no importance!
	$pageobject->{'articles'} = undef;
	
	$pageobject->{'subpage'} = 0;
}

sub extract_file_config {
	my ( $file ) = @_;
	
	my $yaml_lines;
	open my $fh, '<:encoding(utf8)', $file or die "Failed to open $file for input: $!";
	
    my $delimiter = qr/^---\n$/;
    if ( <$fh> =~ $delimiter ) {
        my @yaml_lines;
        while ( my $line = <$fh> ) {
            if ( $line =~ $delimiter ) {
                last;
            }
            push @yaml_lines, $line;
        }
	$yaml_lines = join '', @yaml_lines;
    }
    
    close $fh;
    
    my $yaml_config = Load $yaml_lines;
    return $yaml_config;
}

1;
