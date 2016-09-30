package PLog::UI::Preview;

use 5.006000;
use strict;
use warnings;
use utf8;

use Gtk3;
use Glib('TRUE', 'FALSE');
use Gtk3::WebKit;
use Text::Textile('textile');
use Template;

use Data::Dumper;

require Exporter;

our @ISA = qw(Exporter);

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
	my ($class, %config) = @_;
	
	my $preview_object = \%config;
		
	my $view = Gtk3::WebKit::WebView->new();
	$preview_object->{'view'} = $view;
	
	bless $preview_object;
	
	$preview_object->render_preview('content' => $preview_object->{'content'});
	
	return $preview_object;
}

sub reload {
	my ($self, $content) = @_;
	
	$self->render_preview('content' => $content);
}

sub render_preview {
	my ($self, %options) = @_;
	
	my $view = $self->{'view'};
	
	if ($options{'template'} ) {
		my $abs_layout_path = $options{'template'};
		my $abs_include_path = $main::siteconf->{'include'};
		
		my $template = Template->new(
	        'INCLUDE_PATH' => $abs_include_path,
	        'WRAPPER'      => $abs_layout_path,
		'TAG_STYLE'	=> 'asp',
	        'ABSOLUTE'     => 1,
	    );
	    my $output = '';
	    my $content = "<h1>Lorem ipsum</h1><p>bla bla bla</p>";
	    $template->process( $content, undef, $output )
              or die $template->error;
        
        $view->load_html_string($output, '');
        
	}
	elsif ($options{'css'}) {
	
		my $content = $options{'content'} || $self->{'content'};
		my $css_file = $options{'css'};
		
		my $textile = Text::Textile->new('disable_encode_entities' => 1,
						'charset' => 'utf-8' );
		my $html_content = $textile->process($content);
		
		$html_content = "<!DOCTYPE html>\n
						<html lang=\"de\">\n
						<head>\n
							<meta charset=\"utf-8\">\n
							<link href=\"$css_file\" rel=\"stylesheet\" type=\"text/css\" media=\"all\">\n
						</head>\n
						<body>$html_content</body>\n
						</html>";
		
		$view->load_html_string($html_content, '');
	}
	else {
		my $content = $options{'content'} || $self->{'content'};
		
		# Add the rel base to the links
		my $sv_rel_base = $self->_relative_path ( $self->{'path'} );
		$content =~ s/\<\%\s*sv_rel_base\s*\%\>/$sv_rel_base/g;
	
		my $textile = Text::Textile->new('disable_encode_entities' => 1,
						'charset' => 'utf-8' );
		my $html_content = $textile->process($content);
		my $style = get_preview_style();
		$html_content = "<!DOCTYPE html>\n
						<html lang=\"de\">\n
						<head>\n
							<meta charset=\"utf-8\">\n
							<style>$style</style>
						</head>\n
						<body>$html_content</body>\n
						</html>";
		
		$view->load_string($html_content, 'text/html', 'UTF-8', 'file:///home/maximilian/Dokumente/www-maximilianlika-de/_source/galerie/');
	
	}
}

sub get_preview_style {
	my $style = <<HERE;
	img {
		max-width: 150px;
HERE
	return $style;
}

sub _relative_path {

    my ($self,$dest_file) = @_;

    my ($dummy1,$dest_file_dir,$dummy2) = File::Spec->splitpath( $dest_file );

    my $source = $PLog::siteconf->{'source'};
    my $path;
    $path = $PLog::siteconf->{'source'} if $dest_file =~ m/$PLog::siteconf->{'source'}/;
    $path = $PLog::siteconf->{'blog_source'} if $dest_file =~ m/$PLog::siteconf->{'blog_source'}/;
    my $rel_path = File::Spec->abs2rel ( $path,
                                         $dest_file_dir );

    $rel_path .= "/" if $rel_path;

    return $rel_path;

};

1;
