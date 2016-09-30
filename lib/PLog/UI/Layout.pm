package PLog::UI::Layout;

use 5.006000;
use strict;
use warnings;
use utf8;

use lib ('/home/maximilian/Dokumente/PLog/lib', '/home/maximilian/perl5/lib');

use Gtk3;
use Glib('TRUE', 'FALSE');
use Gtk3::WebKit;
use File::Spec;
use File::Path ('remove_tree', 'make_path');
use YAML;
use Text::Slugify('slugify');
use File::Find;

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


sub start_module {
	my ($widget, $siteobject_ref) = @_;
	our $siteobject = $$siteobject_ref if ($siteobject_ref);
	
	my $content_area = PLog::ContentArea->clean();
	
	# We want 3 pages: Layout, Templates, CSS
	my $notebook = Gtk3::Notebook->new();
	my %tabs = ('layout' => 'Layout',
				'template' => 'Templates',
				'css' => 'CSS');
	my @tabs = ('layout', 'template', 'css');
	
	foreach my $key (@tabs) {
	
		my $layout_label = Gtk3::Label->new("$tabs{$key}");
		my $layout_box = Gtk3::Box->new('vertical',5);
	
		my @layout_files;
		my $layoutdir;
		
		$layoutdir = "$siteobject->{'dir'}" . "/_layouts" if ($key eq 'layout');
		$layoutdir = "$siteobject->{'dir'}" . "/_includes" if ($key eq 'template');
		
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
	$new_button->signal_connect('clicked'=>\&create_layout, [$key_ref, $siteobject]);
	
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
	my ($widget, $vars_ref) = @_;
	my $key = ${ $vars_ref->[0] };
	my $siteobject = $vars_ref->[1];
	
	my $content_area = PLog::ContentArea->clean();
	
	# The next three if/elsif blocks have at the moment the same content!
	# (only $layoutdir is different). But in future releases I want to add
	# some specific assists! Therefor I seperate the function already now!
	if ($key eq 'layout') {
		my $layoutdir = "$siteobject->{'dir'}" . "/_layouts";
	
		my $new_label = Gtk3::Label->new('Name');
		my $new_buffer = Gtk3::EntryBuffer->new(undef,-1);
		my $new_entry = Gtk3::Entry->new_with_buffer($new_buffer);

		my $button = Gtk3::Button->new('Layout anlegen');
		$button->signal_connect('clicked' => sub {
													my $name = $_[1]->get_text();
													my $name_slug = slugify($name);
													my $file = "$layoutdir/$name_slug.tt";
													open my $fh, ">:encoding(utf8)", $file or die "Could not create Layout file";
													close $fh;

													my @variables = ($file , $name);
													edit_single_layout(undef, \@variables);
													}, $new_buffer);
	
		$content_area->pack_start($new_label, FALSE, FALSE, 0);
		$content_area->pack_start($new_entry, FALSE, FALSE, 0);
		$content_area->pack_start($button, FALSE, FALSE, 0);
		$content_area->show_all();
	}
	elsif ($key eq 'template') {
		my $layoutdir = "$siteobject->{'dir'}" . "/_includes";

		my $new_label = Gtk3::Label->new('Name');
		my $new_buffer = Gtk3::EntryBuffer->new(undef,-1);
		my $new_entry = Gtk3::Entry->new_with_buffer($new_buffer);

		my $button = Gtk3::Button->new('Template anlegen');
		$button->signal_connect('clicked' => sub {
													my $name = $_[1]->get_text();
													my $name_slug = slugify($name);
													my $file = "$layoutdir/$name_slug.tt";
													open my $fh, ">:encoding(utf8)", $file or die "Could not create Layout file";
													close $fh;

													my @variables = ($file , $name);
													edit_single_layout(undef, \@variables);
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

		my $button = Gtk3::Button->new('CSS Datei anlegen');
		$button->signal_connect('clicked' => sub {
													my $name = $_[1]->get_text();
													my $name_slug = slugify($name);
													my $file = "$layoutdir/$name_slug.css";
													open my $fh, ">:encoding(utf8)", $file or die "Could not create Layout file";
													close $fh;

													my @variables = ($file , $name);
													edit_single_css(undef, \@variables);
													}, $new_buffer);
		
		$content_area->pack_start($new_label, FALSE, FALSE, 0);
		$content_area->pack_start($new_entry, FALSE, FALSE, 0);
		$content_area->pack_start($button, FALSE, FALSE, 0);
		$content_area->show_all();
	}
}

# The edit_single_layout is for templates, layouts and (!) bloglists
sub edit_single_layout {
	my ($button, $vars_ref) = @_;
	
	my $file = $vars_ref->[0];
	if (ref($file) ) {
		$file = $$file;
	}
	
	# The var $bloglist is true, if the function was called from 
	# the PLog::UI::BlogContent module to edit a bloglist file
	my $bloglist = $vars_ref->[2] || '';
	
	my $content_area = PLog::ContentArea->clean();
	
	my (undef,undef,$name) = File::Spec->splitpath($file);
	
	open my $fh, "<:encoding(utf8)", $file or die "Could not open file: $!\n";
	my ($yaml, $content);
	if ($bloglist) {
		($yaml, $content) = PLog::Generator->_extract_file_config($fh);
	}
	else {
		local $/;
		$content = <$fh>;
		$yaml = '';
	}
	close $fh;
	
	# NAME
	my $name_label = Gtk3::Label->new('Name');
	my $name_buffer = Gtk3::EntryBuffer->new($name,-1);
	my $name_entry = Gtk3::Entry->new_with_buffer($name_buffer);
	
	# $bloglist contains the yaml config of the bloglist page!
	my $pagination;
	if (ref($bloglist) eq 'HASH') {
		$pagination = $bloglist->{'pagination'} || '0' ;
	}
	else {
		$pagination = '0';
	}
	my $pagination_label = Gtk3::Label->new('Pagination/Posts per page (set \'0\', if you want all posts on one single page)');
	my $pagination_ad = Gtk3::Adjustment->new($pagination, 0, 100, 1, 0, 0);
	my $pagination_spin = Gtk3::SpinButton->new($pagination_ad,1,0);
	
	# EDITOR
	my $editor_label = Gtk3::Label->new('Editor');
	my $textbuffer = Gtk3::TextBuffer->new();
	$textbuffer->set_text($content);
	
	my $textview = Gtk3::TextView->new();
	$textview->set_buffer($textbuffer);
	$textview->set_wrap_mode('word');
	
	my $scrolled_window = Gtk3::ScrolledWindow->new();
	$scrolled_window->set_policy('automatic','automatic');
	
	$scrolled_window->add($textview);
	
	# BUTTONS
	my @variables = ($file, $textbuffer, $yaml, $bloglist);
	my $save_button = Gtk3::Button->new('Save');
	$save_button->signal_connect('clicked' => \&edit_single_cb, \@variables);
	
	my $cancel_button = Gtk3::Button->new('Cancel');
	if ($bloglist) {
		$cancel_button->signal_connect('clicked' => sub {PLog::UI::BlogContent::start_module();});
	}
	else {
		$cancel_button->signal_connect('clicked' => sub {start_module();});
	}
	my $hbox = Gtk3::Box->new('horizontal',5);
	$hbox->pack_start($save_button, TRUE, TRUE, 0);
	$hbox->pack_start($cancel_button, TRUE, TRUE, 0);
	
	$content_area->pack_start($name_label, FALSE, FALSE, 0);
	$content_area->pack_start($name_entry, FALSE, FALSE, 0);
	if ($bloglist) {
		# PAGINATION is only shown at bloglist
		$content_area->pack_start($pagination_label, FALSE, FALSE, 0);
		$content_area->pack_start($pagination_spin, FALSE, FALSE, 0);
	}
	$content_area->pack_start($editor_label, FALSE, FALSE, 0);
	$content_area->pack_start($scrolled_window, TRUE, TRUE, 10);
	$content_area->pack_start($hbox, FALSE, FALSE, 10);
	$content_area->show_all();
	
}

# In CSS files we have not a YAML part
sub edit_single_css {
	my ($button, $vars_ref) = @_;
	
	my $file = $vars_ref->[0];
	if (ref($file) ) {
		$file = $$file;
	}
	
	my $content_area = PLog::ContentArea->clean();
	
	my (undef,undef,$name) = File::Spec->splitpath($file);
	
	open my $fh, "<:encoding(utf8)", $file or die "Could not open file: $!\n";
	my $content = '';
	while (my $line = <$fh>) {
		$content = $content . $line;
	}
	close $fh;
	
	# NAME
	my $name_label = Gtk3::Label->new('Name/URL');
	my $name_buffer = Gtk3::EntryBuffer->new($name,-1);
	my $name_entry = Gtk3::Entry->new_with_buffer($name_buffer);
	
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
	$cancel_button->signal_connect('clicked' => sub {start_module();});
	
	my $hbox = Gtk3::Box->new('horizontal',5);
	$hbox->pack_start($save_button, TRUE, TRUE, 0);
	$hbox->pack_start($cancel_button, TRUE, TRUE, 0);
	
	$content_area->pack_start($name_label, FALSE, FALSE, 0);
	$content_area->pack_start($name_entry, FALSE, FALSE, 0);
	$content_area->pack_start($scrolled_window, TRUE, TRUE, 10);
	$content_area->pack_start($hbox, FALSE, FALSE, 10);
	$content_area->show_all();
	
}

#######################
# write to file
######################
sub edit_single_cb {
	my ($button, $varsref) = @_;
	my $file = $varsref->[0];
	
	my $textbuffer = $varsref->[1];
	my $start = $textbuffer->get_start_iter;
	my $end = $textbuffer->get_end_iter;
	my $content = $textbuffer->get_text($start,$end, TRUE);
	
	my $yaml = $varsref->[2];

	open my $fh, ">:encoding(utf8)", $file;
	# $yaml only exits for bloglist files!!!
	if ($yaml) {
	my $yaml_line = Dump($yaml);
		print $fh "$yaml_line---\n" . "$content";
	}
	else {
		print $fh "$content";
	}
	close $fh;
	
	my $bloglist = $varsref->[3] || '';
	if ( $bloglist) {
		PLog::UI::BlogContent::start_module();
	}
	else {
		start_module();
	}
}

#########################
# DELETE LAYOUT
########################
sub delete_layout {
	my ($button, $file_ref) = @_;
	my $file = $$file_ref;
	
	# Really delete?
	my $dialog = Gtk3::Dialog->new();
	$dialog->set_title("Really delete?");
	$dialog->set_transient_for($PLog::window);
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
	
	start_module();
}

1;
