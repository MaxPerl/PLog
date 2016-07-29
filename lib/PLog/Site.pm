package PLog::Site;

use 5.006000;
use strict;
use warnings;
use utf8;

use YAML ('LoadFile', 'Load');
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
	my ($self,$conffile) = @_;
	my $siteobject = LoadFile("$conffile");	
	
	return bless $siteobject;
}

1;
