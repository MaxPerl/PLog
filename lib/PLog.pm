package PLog;

use 5.006000;
use strict;
use warnings;
use utf8;
use Gtk3;
use Glib('TRUE', 'FALSE');
use Gtk3::WebKit;

use Text::Textile('textile');

use YAML ('LoadFile');
use File::Find;
use File::Path ('remove_tree', 'make_path');
use File::Spec;
use Data::Dumper;

use PLog::ContentArea;
use PLog::Site;
use PLog::Pages;
use PLog::Generator;

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

our $VERSION = '0.01';

our $window;
our $siteobject;
our @pages;

sub new {
	$window = shift @_;
	my ($app) = @_;
	$window = bless Gtk3::ApplicationWindow->new($app);
	$window->set_title('PLog - an Offline CMS Program');
	$window->set_default_size(800,600);
	$window->set_icon_name('web-browser-symbolic');
	$window->set_border_width(10);
	
	# Our App has 2 areas: Left are the items right the content
	my $hbox = Gtk3::Box->new('horizontal', 5);
	
	# The entries on the left
	my $left_area = Gtk3::Box->new('vertical', 5);
	my %entries = (	'Build a new Project' => \&build_project, 
					'Open a Site' => \&open_page, 
					'Content' => \&edit_content,
					'Layout' => \&edit_layout,
					'Compile' => \&compile);
	my @entries = ('Build a new Project', 'Open a Site', 'Content', 'Layout', 'Compile');
	
	my $siteobject_ref = \$siteobject;
	foreach my $entry (@entries) {
		my $button = Gtk3::Button->new("$entry");
		$button->signal_connect('clicked'=>$entries{$entry});
		$left_area->pack_start($button, FALSE, FALSE, 5);
	}
	
	# The content area
	my $content_area = PLog::ContentArea->new();
	my $image = Gtk3::Image->new_from_icon_name('web-browser-symbolic', 'dialog');
	my $header = Gtk3::Label->new();
	$header->set_markup('<b>Welcome to PLog - the Offline CMS System written in Perl</b>');
	my $label = Gtk3::Label->new();
	$label->set_text('Please choose an action out of the left area!');
	
	$content_area->pack_start($image, FALSE, FALSE, 10);
	$content_area->pack_start($header, FALSE, FALSE, 0);
	$content_area->pack_start($label, FALSE, FALSE, 0);
	
	$hbox->pack_start($left_area, FALSE, FALSE, 0);
	$hbox->pack_start($content_area, TRUE, TRUE, 0);
	$window->add($hbox);
	return $window;
}

sub page_overview	 {
	
	my $content_area = clean_content_area();
	
	my $title = $siteobject->{'title'};
	my $projectdir = $siteobject->{'dir'};
		
	my $image = Gtk3::Image->new_from_icon_name('web-browser-symbolic', 'dialog');
	my $header = Gtk3::Label->new();
	$header->set_markup("<b>Overview - $title</b>");
	my $label = Gtk3::Label->new();
	$label->set_text("Title of the Website: $title \n Projectdirectory: $projectdir");
	
	$content_area->pack_start($image, FALSE, FALSE, 10);
	$content_area->pack_start($header, FALSE, FALSE, 0);
	$content_area->pack_start($label, FALSE, FALSE, 0);
	$content_area->show_all();
}

sub loadPage {
	my ($conffile) = @_;
	
	# Create the Object of the site with all informations
	# about the Project
	$siteobject = PLog::Site->new($conffile);
	
	# Fill the object container with objects for all pages
	my $projectdir = $siteobject->{'dir'};
	
	find sub {
			my $file = $File::Find::name;
			
			# A page is a directory that contains a file with the name index.markdown or index.textile
			if (-d $file  && -e "$file/index.markdown") {
				my $pageobject = PLog::Pages->new($siteobject,"$file/index.markdown");
				push @pages, $pageobject;
			}
			elsif (-d $file  && -e "$file/index.textile") {
				my $pageobject = PLog::Pages->new($siteobject,"$file/index.textile");
				push @pages, $pageobject;
			}
			
	}, "$projectdir/_source";
	
	
}
sub build_project {
	my $content_area = clean_content_area();
	
	my $image = Gtk3::Image->new_from_icon_name('web-browser-symbolic', 'dialog');
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
	
	$content_area->pack_start($image, FALSE, FALSE, 10);
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
	
	# Create the Project Directory
	mkdir "$project_dir/$title" or die "Could not create Project Directory";
	
	# Create the StaticVolt Filestructure
	mkdir "$project_dir/$title/_includes" or die "Could not create Project Directory";
	mkdir "$project_dir/$title/_layouts" or die "Could not create Project Directory";
	mkdir "$project_dir/$title/_source" or die "Could not create Project Directory";
	mkdir "$project_dir/$title/_site" or die "Could not create Project Directory";

	# Create a config file with the title and the projectdir
	my $conffile = "$project_dir/$title/$title.yaml";
	open my $fh, ">:encoding(utf8)", "$conffile";
	print $fh "---\ntitle: $title\ndir: $project_dir";
	close $fh;
	
	loadPage($conffile);
	page_overview();
}

sub open_page {
	my $content_area = clean_content_area();
	
	my $image = Gtk3::Image->new_from_icon_name('web-browser-symbolic', 'dialog');
	my $header = Gtk3::Label->new();
	$header->set_markup("<b>Open an existing Project</b>");
	my $label = Gtk3::Label->new();
	$label->set_text("Please choose the YAML-file of the Project");
	
	my $filename;
	my $filename_ref = \$filename;
	my $projectdir_button = Gtk3::FileChooserButton->new('Project Directory', 'open');
	$projectdir_button->signal_connect('file-set'=>sub {$filename = $_[0]->get_filename();});
	
	my $button = Gtk3::Button->new('Open the file');
	$button->signal_connect('clicked' => \&open_page_cb, $filename_ref);
	
	$content_area->pack_start($image, FALSE, FALSE, 10);
	$content_area->pack_start($header, FALSE, FALSE, 0);
	$content_area->pack_start($label, FALSE, FALSE, 0);
	$content_area->pack_start($projectdir_button, FALSE, FALSE, 0);
	$content_area->pack_start($button, FALSE, FALSE, 0);
	$content_area->show_all();	
}

sub open_page_cb {
	my ($button, $filename_ref) = @_;
	my $filename = $$filename_ref;
	
	loadPage($filename);
	page_overview();
}

sub edit_content {
	my ($button) = @_;
	
	my $content_area = clean_content_area();
		
	# THE TREEVIEW
	# For displaying the Pages we take a simple TreeView
	my @columns = ('URL', 'Title');
	
	# the data in the model (2 strings for each row)
	my $listmodel = Gtk3::ListStore->new('Glib::String','Glib::String','Glib::String');
	
	# append the values in the model
	for (my $i=0; $i<=$#pages; $i++) {
		my $iter = $listmodel->append();
		# first column = URL, second column = Title, third column = pageobject!!
		$listmodel->set($iter,	0 => "$pages[$i]->{'url'}",
								1 => "$pages[$i]->{'title'}",
								2 => "$i");
	}
	
	# a treeview to see the data stored in the model
	my $view = Gtk3::TreeView->new($listmodel);
	
	# a cell renderer to render the text for each of the 2 columns
	for (my $i=0; $i <= $#columns; $i++) {
		my $cell = Gtk3::CellRendererText->new();
		
		my $col = Gtk3::TreeViewColumn->new_with_attributes($columns[$i],$cell,'text'=>$i);
		
		$view->append_column($col);
	}
	
	# a TreeSelection Objekt
	# we want to pass to the callback functions the page object of the selected page (= $pages[$i]);
	# whereas $i is the actual selected line (see above)
	my $page;
	my $page_ref = \$page;
	my $treeselection = $view->get_selection();
	$treeselection->signal_connect('changed'=> sub {
													my ($sel) = @_;
													
													my ($model, $iter) = $sel->get_selected();
													my $i = $model->get_value($iter,2);
													$page = $pages[$i];
													});
	
	# THE BUTTONS
	my $new_button = Gtk3::Button->new('New');
	$new_button->signal_connect('clicked'=>\&create_page);
	
	my $edit_button = Gtk3::Button->new('Edit');
	$edit_button->signal_connect('clicked' => \&edit_page, $page_ref);
	
	my $del_button = Gtk3::Button->new('Delete');
	$del_button->signal_connect('clicked' => \&delete_page, $page_ref);
	
	my $hbox = Gtk3::Box->new('horizontal',5);
	$hbox->pack_start($new_button, TRUE, TRUE, 0);
	$hbox->pack_start($edit_button, TRUE, TRUE, 0);
	$hbox->pack_start($del_button, TRUE, TRUE, 0);
	
	
	# SHOW ALL
	$content_area->pack_start($view, TRUE, TRUE, 0);
	$content_area->pack_start($hbox, FALSE, FALSE, 0);
	$content_area->show_all();
	
}

sub create_page {
	my $content_area = clean_content_area();
	
	my $image = Gtk3::Image->new_from_icon_name('web-browser-symbolic', 'dialog');
	my $header = Gtk3::Label->new();
	$header->set_markup("<b>Create a new page</b>");
	
	my $name_label = Gtk3::Label->new('Name/URL');
	my $name_buffer = Gtk3::EntryBuffer->new(undef,-1);
	my $name_entry = Gtk3::Entry->new_with_buffer($name_buffer);
	
	my $title_label = Gtk3::Label->new('Title');
	my $title_buffer = Gtk3::EntryBuffer->new(undef,-1);
	my $title_entry = Gtk3::Entry->new_with_buffer($title_buffer);

	my $layout_label = Gtk3::Label->new('Layout File (only Filename)');
	my $layout_buffer = Gtk3::EntryBuffer->new(undef,-1);
	my $layout_entry = Gtk3::Entry->new_with_buffer($layout_buffer);
	
	my @variables = ($name_buffer, $title_buffer, $layout_buffer);
	my $button = Gtk3::Button->new('Create Page');
	$button->signal_connect('clicked' => \&create_page_cb, \@variables);
	
	$content_area->pack_start($image, FALSE, FALSE, 10);
	$content_area->pack_start($header, FALSE, FALSE, 0);
	$content_area->pack_start($name_label, FALSE, FALSE, 0);
	$content_area->pack_start($name_entry, FALSE, FALSE, 0);
	$content_area->pack_start($title_label, FALSE, FALSE, 0);
	$content_area->pack_start($title_entry, FALSE, FALSE, 0);
	$content_area->pack_start($layout_label, FALSE, FALSE, 0);
	$content_area->pack_start($layout_entry, FALSE, FALSE, 0);
	$content_area->pack_start($button, FALSE, FALSE, 0);
	$content_area->show_all();

}

sub create_page_cb {
	my ($button, $varsref) = @_;
	my @variables = @$varsref;
	
	my $name = $variables[0]->get_text();
	my $title = $variables[1]->get_text();
	my $layout = $variables[2]->get_text();
	
	# Create the pagedirectory
	my $projectdirectory = $siteobject->{'dir'};
	my $pagedirectory = "$projectdirectory/_source/$name";
	make_path "$pagedirectory" or die "Could not create Project Directory";
	
	# Create the index.textile file
	my $pagefile = "$pagedirectory/index.textile";
	open my $fh, ">:encoding(utf8)", "$pagefile";
	print $fh "---\ntitle: $title\nurl: $name\nlayout: $layout\n---\n";
	close $fh;
	
	# Add the page object to @pages
	my $pageobject = PLog::Pages->new($siteobject,$pagefile);
	push @pages, $pageobject;
	
	# sort @pages
	@pages = sort {
					if ($a->{'url'} lt $b->{'url'}) {return -1}
					elsif ($a->{'url'} gt $b->{'url'}) {return 1}
					else {return 0}
					} @pages;
	
	edit_content();
}

sub edit_page {
	my ($button, $page_ref) = @_;
	my $page = $$page_ref;
	
	my $content_area = clean_content_area();
	
	my $pagefile = $page->{'pagefile'};
	my $pagedir = $page->{'pagedirectory'};
	print "$pagedir \n";
	my $title = $page->{'title'};
	
	open my $fh, "<:encoding(utf8)", $pagefile;
	
	my @yaml;
	my $content ='';
	while (my $line = <$fh>) {
			if ($line =~ m/^---\n/) {
				push @yaml, $line;
				while (my $yamllines = <$fh>) {
					if ($yamllines =~ m/^---\n/) {
						push @yaml, $yamllines;
						last;
					}
					else {
						push @yaml, $yamllines;
					}
				}
			}
			else {

					$content = $content . $line;
			}
		}
	
	close $fh;
	
	# TITLE
	my $titlelabel = Gtk3::Label->new('Title');
	my $titlebuffer = Gtk3::EntryBuffer->new("$title",-1);
	my $titleentry = Gtk3::Entry->new_with_buffer($titlebuffer);
	
	
	# PREVIEW
	my $textile=Text::Textile->new();
	$textile->charset('utf-8');
	my $html_content = $textile->process($content);
	my $scroll_preview = Gtk3::ScrolledWindow->new();
	my $view = Gtk3::WebKit::WebView->new();
	$view->load_html_string($html_content, '');
	# In later versions: With a base uri, images etc. are visible in the
	# preview. BUT: Then we need a opportunity to import css!!!
	#$view->load_html_string($html_content, "file://$pagedir");
	$scroll_preview->add($view);
	
	
	# EDITOR
	my $textbuffer = Gtk3::TextBuffer->new();
	$textbuffer->set_text($content);
	my @changevariables = ($view, $textbuffer);
	$textbuffer->signal_connect('changed' => \&edit_page_changed, \@changevariables);
	
	my $textview = Gtk3::TextView->new();
	$textview->set_buffer($textbuffer);
	$textview->set_wrap_mode('word');
	
	my $scrolled_window = Gtk3::ScrolledWindow->new();
	$scrolled_window->set_policy('automatic','automatic');
	
	$scrolled_window->add($textview);
	
	# BUTTONS
	my @variables = ($page, $titlebuffer, \@yaml, $textbuffer);
	my $save_button = Gtk3::Button->new('Save');
	$save_button->signal_connect('clicked' => \&edit_page_cb, \@variables);
	
	my $cancel_button = Gtk3::Button->new('Cancel');
	$cancel_button->signal_connect('clicked' => sub {edit_content();});
	
	my $hbox = Gtk3::Box->new('horizontal',5);
	$hbox->pack_start($save_button, TRUE, TRUE, 0);
	$hbox->pack_start($cancel_button, TRUE, TRUE, 0);
	
	
	$content_area->pack_start($titlelabel, FALSE, FALSE, 10);
	$content_area->pack_start($titleentry, FALSE, FALSE, 10);
	$content_area->pack_start($scrolled_window, TRUE, TRUE, 10);
	$content_area->pack_start($scroll_preview, TRUE, TRUE, 10);
	$content_area->pack_start($hbox, FALSE, FALSE, 10);
	$content_area->show_all();
}

sub edit_page_changed {
	my ($button, $varsref) = @_;
	my @variables = @$varsref;
	my $view = $variables[0];
	my $textbuffer = $variables[1];
	my $start = $textbuffer->get_start_iter;
	my $end = $textbuffer->get_end_iter;
	
	my $content = $textbuffer->get_text($start, $end, TRUE);
	my $content_html = textile($content);
	
	$view->load_html_string($content_html, '');
}

sub edit_page_cb {
	my ($button, $varsref) = @_;
	my @variables = @$varsref;
	
	my $page = $variables[0];
	my $pagefile = $page->{'pagefile'};
	my $titlebuffer = $variables[1];
	my $title = $titlebuffer->get_text;
	my $yaml_ref = $variables[2];
	my @yaml = @$yaml_ref;
	my $yaml = '';
	foreach my $yamlline (@yaml) {
		if ($yamlline =~ m/^title:/) {
			$yamlline = "title: $title \n";
			$page->{'title'}=$title;
		}
		$yaml = $yaml . $yamlline;
	}
	my $textbuffer = $variables[3];
	my $start = $textbuffer->get_start_iter;
	my $end = $textbuffer->get_end_iter;
	my $content = $textbuffer->get_text($start,$end, TRUE);
	
	open my $fh, ">:encoding(utf8)", $pagefile;
	print $fh "$yaml" . "$content";
	close $fh;
	
	edit_content();
}

sub delete_page {
	my ($button, $page_ref) = @_;
	my $page = $$page_ref;
	
	# Really delete?
	my $dialog = Gtk3::Dialog->new();
	$dialog->set_title('Really delete the Page?');
	$dialog->set_transient_for($window);
	$dialog->set_modal(TRUE);
	$dialog->set_default_size(300,150);
	
	# Add button Yes and No
	$dialog->add_button('Yes','yes');
	$dialog->add_button('No','no');
	
	$dialog->signal_connect('response'=>\&delete_page_cb, $page_ref);
	
	# Get the content area of the dialog and add the question
	my $content_area = $dialog->get_content_area();
	my $url = $page->{'url'};
	my $pagedirectory = $page->{'pagedirectory'};
	my $label = Gtk3::Label->new("Do you really want to delete the Page '$url', all supages of this page and all static files saved in the pagedirectory ($pagedirectory)?");
	$label->set_line_wrap(TRUE);
	$content_area->add($label);
	
	$dialog->show_all();
}

sub delete_page_cb {
	my ($dialog, $response_id, $page_ref) = @_;
	my $page = $$page_ref;
	
	if ($response_id eq 'yes') {
		# Delete the pagedirectory and all files inside
		my $pagedirectory = $page->{'pagedirectory'};
		remove_tree($pagedirectory);
	
		# unshift the pageobject from the @pages object container
		for (my $i=0; $i<=$#pages; $i++) {
			# you get the adress of the reference with + 0
			my $pages_i_adress = $pages[$i] + 0;
			my $page_adress = $page + 0;
			
			if ($pages_i_adress == $page_adress) {
				splice @pages, $i, 1;
				$i--;
			}
		
		$dialog->destroy();
		}
	}
	else {
		$dialog->destroy();
	}
	
	edit_content();
}

sub edit_layout {
	my $content_area = clean_content_area();
	
	# We want 3 pages: Layout, Templates, CSS
	my $notebook = Gtk3::Notebook->new();
	my %tabs = ('layout' => 'Layout',
				'templates' => 'Templates',
				'css' => 'CSS');
	my @tabs = ('layout', 'templates', 'css');
	
	foreach my $key (@tabs) {
	
		my $layout_label = Gtk3::Label->new("$tabs{$key}");
		my $layout_box = Gtk3::Box->new('vertical',5);
	
		my @layout_files;
		my $layoutdir;
		
		$layoutdir = "$siteobject->{'dir'}" . "/_layouts" if ($key eq 'layout');
		$layoutdir = "$siteobject->{'dir'}" . "/_includes" if ($key eq 'templates');
		
		# The css directory is not created by default. Therefore create it
		# it doesn't exist already!
		my $cssdir = "$siteobject->{'dir'}"."/_source/media/css";
		make_path("$cssdir") unless (-e $cssdir);
		
		$layoutdir = "$siteobject->{'dir'}" . "/_source/media/css" if ($key eq 'css');

		if ($key eq 'css')  {
			find sub {
					my $file = $File::Find::name;
			
					# A page is a directory that contains a file with the extension "*.tt"
					if ($file =~ m/\.css$/) {
						push @layout_files, $file;
					}
			
			}, "$layoutdir";
		}
		else {	
			find sub {
					my $file = $File::Find::name;
			
					# A page is a directory that contains a file with the extension "*.tt"
					if ($file =~ m/\.tt$/) {
						push @layout_files, $file;
					}
			
			}, "$layoutdir";
	}
	
	# THE TREEVIEW
	# For displaying the Pages we take a simple TreeView
	my @columns = ('Name');
	
	# the data in the model (2 strings for each row)
	my $listmodel = Gtk3::ListStore->new('Glib::String', 'Glib::String');
	
	# append the values in the model
	for (my $i=0; $i<=$#layout_files; $i++) {
		my $iter = $listmodel->append();
		# first column = URL, second column = Title, third column = pageobject!!
		$listmodel->set($iter,	0 => "$layout_files[$i]",
								1 => "$key");
	}
	
	# a treeview to see the data stored in the model
	my $view = Gtk3::TreeView->new($listmodel);
	
	# a cell renderer to render the text for each of the 2 columns
	for (my $i=0; $i <= $#columns; $i++) {
		my $cell = Gtk3::CellRendererText->new();
		
		my $col = Gtk3::TreeViewColumn->new_with_attributes($columns[$i],$cell,'text'=>$i);
		
		$view->append_column($col);
	}
	
	# a TreeSelection Objekt
	# we want to pass to the callback functions the page object of the selected page (= $pages[$i]);
	# whereas $i is the actual selected line (see above)
	my $layout_file;
	my $layout_file_ref = \$layout_file;
	my $key_ref = \$key;
	my $treeselection = $view->get_selection();
	$treeselection->signal_connect('changed'=> sub {
													my ($sel) = @_;
													
													my ($model, $iter) = $sel->get_selected();
													$layout_file = $model->get_value($iter,0);
													$key = $model->get_value($iter,1);
													});
	
	# THE BUTTONS
	my $new_button = Gtk3::Button->new('New');
	$new_button->signal_connect('clicked'=>\&create_layout, $key_ref);
	
	my @vars = ($layout_file_ref,$key_ref);
	my $edit_button = Gtk3::Button->new('Edit');
	$edit_button->signal_connect('clicked' => \&edit_single_layout, \@vars);
	
	my $del_button = Gtk3::Button->new('Delete');
	$del_button->signal_connect('clicked' => \&delete_layout, $layout_file_ref);
	
	my $hbox = Gtk3::Box->new('horizontal',5);
	$hbox->pack_start($new_button, TRUE, TRUE, 0);
	$hbox->pack_start($edit_button, TRUE, TRUE, 0);
	$hbox->pack_start($del_button, TRUE, TRUE, 0);
	
	
	# SHOW ALL
	$layout_box->pack_start($view, TRUE, TRUE, 0);
	$layout_box->pack_start($hbox, FALSE, FALSE, 0);
	$layout_box->show_all();
	$notebook->append_page($layout_box, $layout_label);
	}
	
	$notebook->show_all();
	$content_area->pack_start($notebook, TRUE, TRUE, 0);
}

sub create_layout {	
	my ($widget, $key_ref) = @_;
	my $key = $$key_ref;
	my $content_area = clean_content_area();
	
	# The next three if/elsif blocks have at the moment the same content!
	# (only $layoutdir is different). But in future releases I want to add
	# some specific assists! Therefor I seperate the function already now!
	if ($key eq 'layout') {
		my $layoutdir = "$siteobject->{'dir'}" . "/_layouts";
	
		my $new_label = Gtk3::Label->new('Name');
		my $new_buffer = Gtk3::EntryBuffer->new(undef,-1);
		my $new_entry = Gtk3::Entry->new_with_buffer($new_buffer);

		my $button = Gtk3::Button->new('Projekt anlegen');
		$button->signal_connect('clicked' => sub {
													my $name = $_[1]->get_text();
													open my $fh, ">:encoding(utf8)", "$layoutdir/$name.tt" or die "Could not create Layout file";
													my $file = "$layoutdir/$name.tt";
													my @variables = (\$file , $name);
													edit_single_layout(undef, \@variables);
													}, $new_buffer);
	
		$content_area->pack_start($new_label, FALSE, FALSE, 0);
		$content_area->pack_start($new_entry, FALSE, FALSE, 0);
		$content_area->pack_start($button, FALSE, FALSE, 0);
		$content_area->show_all();
	}
	elsif ($key eq 'templates') {
		my $layoutdir = "$siteobject->{'dir'}" . "/_includes";

		my $new_label = Gtk3::Label->new('Name');
		my $new_buffer = Gtk3::EntryBuffer->new(undef,-1);
		my $new_entry = Gtk3::Entry->new_with_buffer($new_buffer);

		my $button = Gtk3::Button->new('Projekt anlegen');
		$button->signal_connect('clicked' => sub {
													my $name = $_[1]->get_text();
													open my $fh, ">:encoding(utf8)", "$layoutdir/$name.tt" or die "Could not create Layout file";
													my $file = "$layoutdir/$name.tt";
													my @variables = (\$file , $name);
													edit_single_template(undef, \@variables);
													}, $new_buffer);
	
		$content_area->pack_start($new_label, FALSE, FALSE, 0);
		$content_area->pack_start($new_entry, FALSE, FALSE, 0);
		$content_area->pack_start($button, FALSE, FALSE, 0);
		$content_area->show_all();
	}
	elsif ($key eq 'css') {
		my $layoutdir = "$siteobject->{'dir'}" . "/_source/media/css";

		my $new_label = Gtk3::Label->new('Name');
		my $new_buffer = Gtk3::EntryBuffer->new(undef,-1);
		my $new_entry = Gtk3::Entry->new_with_buffer($new_buffer);

		my $button = Gtk3::Button->new('Projekt anlegen');
		$button->signal_connect('clicked' => sub {
													my $name = $_[1]->get_text();
													open my $fh, ">:encoding(utf8)", "$layoutdir/$name.tt" or die "Could not create Layout file";
													my $file = "$layoutdir/$name.css";
													my @variables = (\$file , $name);
													edit_single_css(undef, \@variables);
													}, $new_buffer);
	
		$content_area->pack_start($new_label, FALSE, FALSE, 0);
		$content_area->pack_start($new_entry, FALSE, FALSE, 0);
		$content_area->pack_start($button, FALSE, FALSE, 0);
		$content_area->show_all();
	}
}

# The edit_single_* functions are almost the same. But I want to add specific assists.
# Perhaps do in future releases one function!
sub edit_single_layout {
	my ($button, $vars_ref) = @_;
	my @vars = @$vars_ref;
	my $file_ref = $vars[0];
	my $file = $$file_ref;
	my $name = $vars[1];
	
	my $content_area = clean_content_area();
	
	unless ($name) {
		(undef,undef,$name) = File::Spec->splitpath($file);
		$name =~ s/\.tt$//;
	}
	
	open my $fh, "<:encoding(utf8)", $file;
	my $content ='';
	while (my $line=<$fh>) {
		$content .= $line
	}
	close $fh;
	
	# EDITOR
	my $textbuffer = Gtk3::TextBuffer->new();
	$textbuffer->set_text($content);
	
	my $textview = Gtk3::TextView->new();
	$textview->set_buffer($textbuffer);
	$textview->set_wrap_mode('word');
	
	my $scrolled_window = Gtk3::ScrolledWindow->new();
	$scrolled_window->set_policy('automatic','automatic');
	
	$scrolled_window->add($textview);
	
	# BUTTONS
	my @variables = ($file, $textbuffer);
	my $save_button = Gtk3::Button->new('Save');
	$save_button->signal_connect('clicked' => \&edit_single_cb, \@variables);
	
	my $cancel_button = Gtk3::Button->new('Cancel');
	$cancel_button->signal_connect('clicked' => sub {edit_layout();});
	
	my $hbox = Gtk3::Box->new('horizontal',5);
	$hbox->pack_start($save_button, TRUE, TRUE, 0);
	$hbox->pack_start($cancel_button, TRUE, TRUE, 0);
	
	
	$content_area->pack_start($scrolled_window, TRUE, TRUE, 10);
	$content_area->pack_start($hbox, FALSE, FALSE, 10);
	$content_area->show_all();
	
}

sub edit_single_template {
	my ($button, @vars) = @_;
	my $file_ref = $vars[0];
	my $file = $$file_ref;
	my $name = $vars[1];
	
	my $content_area = clean_content_area();
	
	unless ($name) {
		(undef,undef,$name) = File::Spec->splitpath($file);
		$name =~ s/\.tt$//;
	}
	
	open my $fh, "<:encoding(utf8)", $file;
	my $content ='';
	while (my $line=<$fh>) {
		$content .= $line
	}
	close $fh;
	
	# EDITOR
	my $textbuffer = Gtk3::TextBuffer->new();
	$textbuffer->set_text($content);
	
	my $textview = Gtk3::TextView->new();
	$textview->set_buffer($textbuffer);
	$textview->set_wrap_mode('word');
	
	my $scrolled_window = Gtk3::ScrolledWindow->new();
	$scrolled_window->set_policy('automatic','automatic');
	
	$scrolled_window->add($textview);
	
	# BUTTONS
	my @variables = ($file, $textbuffer);
	my $save_button = Gtk3::Button->new('Save');
	$save_button->signal_connect('clicked' => \&edit_single_cb, \@variables);
	
	my $cancel_button = Gtk3::Button->new('Cancel');
	$cancel_button->signal_connect('clicked' => sub {edit_layout();});
	
	my $hbox = Gtk3::Box->new('horizontal',5);
	$hbox->pack_start($save_button, TRUE, TRUE, 0);
	$hbox->pack_start($cancel_button, TRUE, TRUE, 0);
	
	
	$content_area->pack_start($scrolled_window, TRUE, TRUE, 10);
	$content_area->pack_start($hbox, FALSE, FALSE, 10);
	$content_area->show_all();
	
}

sub edit_single_css {
	my ($button, @vars) = @_;
	my $file_ref = $vars[0];
	my $file = $$file_ref;
	my $name = $vars[1];
	
	my $content_area = clean_content_area();
	
	unless ($name) {
		(undef,undef,$name) = File::Spec->splitpath($file);
		$name =~ s/\.css$//;
	}
	
	open my $fh, "<:encoding(utf8)", $file;
	my $content ='';
	while (my $line=<$fh>) {
		$content .= $line
	}
	close $fh;
	
	# EDITOR
	my $textbuffer = Gtk3::TextBuffer->new();
	$textbuffer->set_text($content);
	
	my $textview = Gtk3::TextView->new();
	$textview->set_buffer($textbuffer);
	$textview->set_wrap_mode('word');
	
	my $scrolled_window = Gtk3::ScrolledWindow->new();
	$scrolled_window->set_policy('automatic','automatic');
	
	$scrolled_window->add($textview);
	
	# BUTTONS
	my @variables = ($file, $textbuffer);
	my $save_button = Gtk3::Button->new('Save');
	$save_button->signal_connect('clicked' => \&edit_single_cb, \@variables);
	
	my $cancel_button = Gtk3::Button->new('Cancel');
	$cancel_button->signal_connect('clicked' => sub {edit_layout();});
	
	my $hbox = Gtk3::Box->new('horizontal',5);
	$hbox->pack_start($save_button, TRUE, TRUE, 0);
	$hbox->pack_start($cancel_button, TRUE, TRUE, 0);
	
	
	$content_area->pack_start($scrolled_window, TRUE, TRUE, 10);
	$content_area->pack_start($hbox, FALSE, FALSE, 10);
	$content_area->show_all();
	
}

# Perhaps create one function write to file for edit_page_cb and edit_single_cb???
sub edit_single_cb {
	my ($button, $varsref) = @_;
	my @variables = @$varsref;
	
	my $file = $variables[0];
	
	my $textbuffer = $variables[1];
	my $start = $textbuffer->get_start_iter;
	my $end = $textbuffer->get_end_iter;
	my $content = $textbuffer->get_text($start,$end, TRUE);
	
	open my $fh, ">:encoding(utf8)", $file;
	print $fh "$content";
	close $fh;
	
	edit_layout();
}

sub delete_layout {
	my ($button, $file_ref) = @_;
	my $file = $$file_ref;
	
	# Really delete?
	my $dialog = Gtk3::Dialog->new();
	$dialog->set_title("Really delete?");
	$dialog->set_transient_for($window);
	$dialog->set_modal(TRUE);
	$dialog->set_default_size(300,150);
	
	# Add button Yes and No
	$dialog->add_button('Yes','yes');
	$dialog->add_button('No','no');
	
	$dialog->signal_connect('response'=>\&delete_layout_cb, $file);
	
	# Get the content area of the dialog and add the question
	my $content_area = $dialog->get_content_area();
	my $label = Gtk3::Label->new("Do you really want to delete $file?");
	$label->set_line_wrap(TRUE);
	$content_area->add($label);
	
	$dialog->show_all();
}

sub delete_layout_cb {
	my ($dialog, $response_id, $file) = @_;
	
	if ($response_id eq 'yes') {
		# Delete the pagedirectory and all files inside
		unlink($file);
		
		$dialog->destroy();
		}
	else {
		$dialog->destroy();
	}
	
	edit_layout();
}

sub clean_content_area {
	my $content_area = PLog::ContentArea->get_content_area();
	$content_area->clean;
	return $content_area;
}

sub compile {
	my $projectdir = $siteobject->{'dir'};
	my $staticvolt = PLog::Generator->new(
		'includes' 	=>	"$projectdir/_includes",
		'layouts'	=>	"$projectdir/_layouts",
		'source'	=>	"$projectdir/_source",
		'destination'	=> "$projectdir/_site",
	);
	
	$staticvolt->compile;
	
	my $content_area = clean_content_area();
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
