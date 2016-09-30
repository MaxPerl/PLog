package PLog;

use 5.006000;
use strict;
use warnings;
use utf8;
use Gtk3;
use Glib('TRUE', 'FALSE');

use File::Find;
use File::Spec;
use YAML('LoadFile');
use Text::Slugify('slugify');

use PLog::ContentArea;
use PLog::Generator;

use PLog::UI::StaticContent;
use PLog::UI::BlogContent;
use PLog::UI::Layout;

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

our $VERSION = '0.07';

our $window;
our $siteobject;
our $siteconf;

sub new {
	$window = shift @_;
	my ($app) = @_;
	$window = bless Gtk3::ApplicationWindow->new($app);
	$window->set_title('PLog - an Offline CMS Program');
	$window->set_default_size(1024,740);
	$window->set_icon_name('web-browser-symbolic');
	$window->set_border_width(10);
	
	# Our App has 2 areas: Left are the items right the content
	my $grid = Gtk3::Grid->new();
	$grid->set_column_spacing(10);
	
	# The entries on the left
	my $left_area = Gtk3::Box->new('vertical', 5);
	my %entries = (	'Build a new Project' => [\&build_project, undef], 
					'Open a Site' => [\&open_page, undef],
					'Page Overview' => [\&page_overview],
					'Static Content' => [\&PLog::UI::StaticContent::start, \$siteconf],
					'Blog Content' => [\&PLog::UI::BlogContent::start_module, \$siteconf],
					'Layout' => [\&PLog::UI::Layout::start_module, \$siteobject],
					'Compile' => [\&compile, undef]);
	my @entries = ('Page Overview','Build a new Project', 'Open a Site', 'Static Content', 'Blog Content', 'Layout', 'Compile');
	
	foreach my $entry (@entries) {
		my $button = Gtk3::Button->new("$entry");
		$button->signal_connect('clicked'=>$entries{$entry}->[0],$entries{$entry}->[1]);
		$left_area->pack_start($button, FALSE, FALSE, 5);
	}
	
	# The content area
	my $content_area = PLog::ContentArea->new();
	$content_area->set_vexpand('TRUE');
	$content_area->set_hexpand('TRUE');
	my $image = Gtk3::Image->new_from_icon_name('web-browser-symbolic', 'dialog');
	my $header = Gtk3::Label->new();
	$header->set_markup('<b>PLog - the Offline CMS System written in Perl</b>');
	my $label = Gtk3::Label->new();
	$label->set_text('Please choose an action out of the left area!');
	
	$grid->attach($left_area, 0, 0, 1, 8);
	$grid->attach($image, 1,0,1,1);
	$grid->attach($header, 1,1,1,1);
	$grid->attach($content_area, 1,2,1,6);
	
	$window->add($grid);
	return $window;
}

sub page_overview	 {
	my $content_area = PLog::ContentArea->clean();
	
	my $title = $siteobject->{'title'};
	my $projectdir = $siteobject->{'dir'};
		
	my $header = Gtk3::Label->new();
	$header->set_markup("<b>Overview</b>");
	my $label = Gtk3::Label->new();
	$label->set_text("Title of the Website: $title \n Projectdirectory: $projectdir");
	
	$content_area->pack_start($header, FALSE, FALSE, 0);
	$content_area->pack_start($label, FALSE, FALSE, 0);
	$content_area->show_all();
}

sub loadPage {
	my ($conffile) = @_;
	
	# Create the SiteObject of the site with all informations
	# about the Project
	$siteobject = LoadFile("$conffile");
	my $projectdir = $siteobject->{'dir'};
	undef $siteconf;
	$siteconf = PLog::Generator->new(
		'includes' 	=>	"$projectdir/_includes",
		'layouts'	=>	"$projectdir/_layouts",
		'source'	=>	"$projectdir/_source",
		'destination'	=> "$projectdir/_site",
		'blog_source' => "$projectdir/_blog_source",
		'blog_destination' => "$projectdir/_site/blog",
        'siteconf' => "$conffile"
	);
}
sub build_project {
	my $content_area = PLog::ContentArea->clean();
	
	my $header = Gtk3::Label->new();
	$header->set_markup("<b>Create a new page</b>");
	my $label = Gtk3::Label->new();
	
	my $title_label = Gtk3::Label->new('Title');
	my $title_buffer = Gtk3::EntryBuffer->new(undef,-1);
	my $title_entry = Gtk3::Entry->new_with_buffer($title_buffer);

	my $filename;
	my $filename_ref = \$filename;
	my $projectdir_button = Gtk3::FileChooserButton->new('Project Directory', 'select-folder');
	$projectdir_button->signal_connect('file-set'=>sub {$filename = $_[0]->get_filename();});
	
	my @variables = ($title_buffer, $filename_ref);
	my $button = Gtk3::Button->new('Create the Project');
	$button->signal_connect('clicked' => \&build_page_cb, \@variables);
	
	$content_area->pack_start($header, FALSE, FALSE, 0);
	$content_area->pack_start($title_label, FALSE, FALSE, 0);
	$content_area->pack_start($title_entry, FALSE, FALSE, 0);
	$content_area->pack_start($projectdir_button, FALSE, FALSE, 0);
	$content_area->pack_start($button, FALSE, FALSE, 0);
	$content_area->show_all();	
}

sub build_page_cb {
	my ($button, $varsref) = @_;
	my @variables = @$varsref;
	my $title = $variables[0]->get_text();
	my $dir_ref = $variables[1];
	my $project_dir = $$dir_ref;
	
	# Slugify $projectdir and $title
	$project_dir = slugify($project_dir);
	my $title_slug = slugify($title);
	
	# Create the Project Directory
	mkdir "$project_dir/$title_slug" or die "Could not create Project Directory";
	
	# Create the StaticVolt Filestructure
	mkdir "$project_dir/$title_slug/_includes" or die "Could not create Project Directory";
	mkdir "$project_dir/$title_slug/_layouts" or die "Could not create Project Directory";
	mkdir "$project_dir/$title_slug/_source" or die "Could not create Project Directory";
	mkdir "$project_dir/$title_slug/_blog_source" or die "Could not create Project Directory";
	mkdir "$project_dir/$title_slug/_site" or die "Could not create Project Directory";

	# Create a config file with the title and the projectdir
	my $conffile = "$project_dir/$title_slug/config.yaml";
	open my $fh, ">:encoding(utf8)", "$conffile";
	print $fh "---\ntitle: $title\ndir: $project_dir/$title_slug";
	close $fh;
	
	loadPage($conffile);
	page_overview();
}

sub open_page {
	my $content_area = PLog::ContentArea->clean();
	
	my $label = Gtk3::Label->new();
	$label->set_text("Please choose the YAML-file of the Project");
	
	my $filename;
	my $filename_ref = \$filename;
	my $projectdir_button = Gtk3::FileChooserButton->new('Project Directory', 'open');
	$projectdir_button->signal_connect('file-set'=>sub {$filename = $_[0]->get_filename();});
	
	my $button = Gtk3::Button->new('Open the file');
	$button->signal_connect('clicked' => \&open_page_cb, $filename_ref);
	
	$content_area->pack_start($label, FALSE, FALSE, 0);
	$content_area->pack_start($projectdir_button, FALSE, FALSE, 0);
	$content_area->pack_start($button, FALSE, FALSE, 0);
	$content_area->show_all();	
}

sub open_page_cb {
	my ($button, $filename_ref) = @_;
	my $filename = $$filename_ref;
	
	loadPage($filename);
	
	my $gtk_recent_manager = Gtk3::RecentManager::get_default();
	my $erfolg = $gtk_recent_manager->add_item("$filename");
	my $items = $gtk_recent_manager->get_items();
	my $firstitem = $items->[0];
	my $uri = $firstitem->get_uri();
	page_overview();
}	

sub compile {
	my $projectdir = $siteobject->{'dir'};
	
	$siteconf->compile;
	
	my $content_area = PLog::ContentArea->clean();
	my $label = Gtk3::Label->new();
	$label->set_text("Congratulation! The site created just fine! You can find the compiled Homepage at $projectdir/_site. Please upload the homepage with a ftp client or with git on the server!");
	$label->set_line_wrap(TRUE);
	$content_area->pack_start($label, TRUE, TRUE, 10);
	$content_area->show_all(); 
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

PLog - Perl extension for blah blah blah

=head1 SYNOPSIS

  use PLog;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for PLog, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Maximilian Lika, E<lt>maximilian@(none)E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Maximilian Lika

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.22.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
