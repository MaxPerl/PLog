package PLog::UI::StaticContent;

use 5.006000;
use strict;
use warnings;
use utf8;

use Gtk3;
use Glib('TRUE', 'FALSE');
use Gtk3::WebKit;
use Data::Dumper;
use File::Path ('remove_tree', 'make_path');
use YAML('Load');
use Text::Slugify('slugify');

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

our @pages;

sub start {
	my ($button, $siteconf_ref) = @_;
	
	# Load the blogconfaliases only the first time, when the blogconf_ref is given!
	if ($siteconf_ref) {
		my $siteconf = $$siteconf_ref;
	
		# Create a Alias for the Pages Arrayreference in $siteconf->{'pages'}
		if (defined $siteconf->{'pages'} ) {
			*pages = $siteconf->{'pages'};
		}
		else {
			@pages = ();
		}
	}
	
	my $content_area = PLog::ContentArea->clean();
		
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
	$new_button->signal_connect('clicked'=>\&create_page, \@pages);
	
	my $edit_button = Gtk3::Button->new('Edit');
	$edit_button->signal_connect('clicked' => \&edit_page, $page_ref);
	
	my $del_button = Gtk3::Button->new('Delete');
	$del_button->signal_connect('clicked' => \&delete_page, [$page_ref, \@pages]);
	
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
	my ($widget, $pages_ref) = @_;
	my $content_area = PLog::ContentArea->clean();
	
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
	
	my @variables = ($pages_ref, $name_buffer, $title_buffer, $layout_buffer);
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
	
	my $name = $variables[1]->get_text();
	my $name_slug = slugify($name);
	my $title = $variables[2]->get_text();
	my $layout = $variables[3]->get_text();
	
	# Create the pagedirectory and pagefile
	my $source_directory = $PLog::siteconf->{'source'};
	$source_directory =~ s/\/$//; 
	my $pagedirectory = "$source_directory/$name_slug";
	make_path "$pagedirectory" or die "Could not create Project Directory";
	my $pagefile = "$pagedirectory/index.textile";
	
	# Add the page object to @pages
	my $pageobject;
	
	my $url = File::Spec->abs2rel($pagedirectory, $source_directory);
	
	# the root site shall be shown as "/"
	$url = "/$url";
	
	$pageobject->{'url'} = $url;
	$pageobject->{'title'} = $title;
	$pageobject->{'pagedirectory'} = $pagedirectory;
	$pageobject->{'pagefile'} = $pagefile;
	$pageobject->{'layout'} = $layout;
	
	# this could be important in latter versions!
	# At the moment no importance!
	$pageobject->{'articles'} = undef;
	$pageobject->{'subpage'} = 0;
	
	push @pages, $pageobject;
	
	# sort @pages
	@pages = sort {
					if ($a->{'url'} lt $b->{'url'}) {return -1}
					elsif ($a->{'url'} gt $b->{'url'}) {return 1}
					else {return 0}
					} @pages;
					
	# Create the index.textile file
	open my $fh, ">:encoding(utf8)", "$pagefile";
	my $yaml_lines = Dump($pageobject);
	print $fh "$yaml_lines---\n";
	close $fh;
	
	start();
}

sub edit_page {
	my ($button, $page_ref) = @_;
	my $page = $$page_ref;

	my $content_area = PLog::ContentArea->clean();
	
	my $pagefile = $page->{'filename'};
	my $pagedir = $page->{'pagedirectory'};
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
	my $scroll_preview = Gtk3::ScrolledWindow->new();
	my $preview = PLog::UI::Preview->new(	'content' => $content,
						'path' => $pagefile);
	$scroll_preview->add($preview->{'view'});
	
	
	# EDITOR
	my $textbuffer = Gtk3::TextBuffer->new();
	$textbuffer->set_text($content);
	my @changevariables = ($preview, $textbuffer);
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
	$cancel_button->signal_connect('clicked' => sub {start();});
	
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
	my $preview = $variables[0];
	my $textbuffer = $variables[1];
	my $start = $textbuffer->get_start_iter;
	my $end = $textbuffer->get_end_iter;
	
	my $content = $textbuffer->get_text($start, $end, TRUE);
	
	$preview->reload($content);
}

sub edit_page_cb {
	my ($button, $varsref) = @_;
	my @variables = @$varsref;
	
	my $page = $variables[0];
	my $pagefile = $page->{'filename'};
	my $titlebuffer = $variables[1];
	my $title = $titlebuffer->get_text;
	$page->{'title'} = $title;
	
	my $yaml = '';
	foreach my $key (keys %$page) {
		my $yamlline = "$key: " . $page->{"$key"} . " \n";
		$yaml = $yaml . $yamlline;
	}
	
	my $textbuffer = $variables[3];
	my $start = $textbuffer->get_start_iter;
	my $end = $textbuffer->get_end_iter;
	my $content = $textbuffer->get_text($start,$end, TRUE);
	
	open my $fh, ">:encoding(utf8)", $pagefile;
	print $fh "---\n$yaml---\n" . "$content";
	close $fh;
	
	if ($page->{'type'} eq 'bloglist') {
		#PLog::UI::BlogContent->start_module(\$PLog::blogconf);
		PLog::UI::BlogContent->start_module();
	}
	else {
		start();
	}
}

sub delete_page {
	my ($button, $vars_ref) = @_;
	my $page_ref = $vars_ref->[0]; 
	my $pages_ref = $vars_ref->[1];
	my $page = $$page_ref;
	
	# Really delete?
	my $dialog = Gtk3::Dialog->new();
	$dialog->set_title('Really delete the Page?');
	$dialog->set_transient_for($PLog::window);
	$dialog->set_modal(TRUE);
	$dialog->set_default_size(300,150);
	
	# Add button Yes and No
	$dialog->add_button('Yes','yes');
	$dialog->add_button('No','no');
	
	$dialog->signal_connect('response'=>\&delete_page_cb, $page_ref, $pages_ref);
	
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
	my ($dialog, $response_id, $page_ref, $pages_ref) = @_;
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
	
	start();
}

1;
