package PLog::ContentArea;

use 5.006000;
use strict;
use warnings;
use utf8;
use Gtk3;
use Glib('TRUE', 'FALSE');

require Exporter;

our @ISA = qw(Exporter Gtk3::Box);

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

my $content_area;

sub new {
	my ($self) = @_;
	$self = bless Gtk3::Box->new('vertical', 5);
	$content_area = $self;
	return $self;
}

sub get_content_area {
	return $content_area;
}

sub clean {
	my ($self) = @_;
	
	my @children = $self->get_children();
	foreach my $children (@children) {
		$children->destroy();
	}
	return 1;
}

return 1;
