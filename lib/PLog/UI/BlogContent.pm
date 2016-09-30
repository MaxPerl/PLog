package PLog::UI::BlogContent;

use 5.006000;
use strict;
use warnings;
use utf8;

use Gtk3;
use Glib('TRUE', 'FALSE');
use Gtk3::WebKit;
use File::Spec;
use File::Path ('remove_tree', 'make_path');
use YAML;
use Text::Slugify('slugify');

use PLog::Generator;
use PLog::UI::Preview;

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

our @blogposts;
our @bloglists;

sub start_module {
	my ($button, $blogconf_ref) = @_;
	
	# Load the blogconfaliases only the first time, when the blogconf_ref is given!
	if ($blogconf_ref) {
		my $blogconf = $$blogconf_ref if ($blogconf_ref);
	
		# Create an alias to the blogposts array in $blogconf->{'posts'}
		if (defined $blogconf->{'posts'} ) {
			*blogposts = $blogconf->{'posts'};
			*bloglists = $blogconf->{'blogindexfiles'};
		}
		else {
			@blogposts = ();
			@bloglists = ();
		}
	}
	
	my $content_area = PLog::ContentArea->clean();
	
	# We want 2 pages: Blog Posts, Blog Lists Pages
	my $notebook = Gtk3::Notebook->new();
	my %tabs = ('blog_posts' => 'Blog Posts',
				'blog_lists' => 'Blog List Pages');
	my @tabs = ('blog_posts', 'blog_lists');
	
	foreach my $key (@tabs) {
	
		my $layout_label = Gtk3::Label->new("$tabs{$key}");
		my $layout_box = Gtk3::Box->new('vertical',5);
		
		my @titles;
		my @files;
		my @dates;
		my @tags;
			
		if ($key eq 'blog_posts') {
			
			foreach my $blogpost (@blogposts) {
				my $title = $blogpost->{'title'};
				push @titles, $title;
				
				my $filename = $blogpost->{'filename'};
				push @files, $filename;
				
				my $date = $blogpost->{'date_raw'};
				$date =~ /^(\d{4})(\d{2})(\d{2})/;
				$date = "$1-$2-$3";
				push @dates, $date;
				
				my @tags_list = @{$blogpost->{'tags'} };
				my $tags = "@tags_list";
				push @tags, $tags;
				#push @tags, "@tags_list";
				 
			}
		}
		elsif ($key eq 'blog_lists') {
			foreach my $bloglist (@bloglists) {
				my $filename = $bloglist->{'filename'};
				push @files, $filename;
				
				my $projectdir = $PLog::siteobject->{'dir'};
				my $rel_path = File::Spec->abs2rel("$filename", "$projectdir/_blog_source");
				$rel_path = "/blog/$rel_path";
				push @titles, $rel_path; 
				
			}
		}
		
		# THE TREEVIEW
	
		# the data in the model (5 strings for each row)
		my $listmodel = Gtk3::ListStore->new('Glib::String', 'Glib::String','Glib::String', 'Glib::String', 'Glib::String');
	
		# append the values in the model
		for (my $i=0; $i<=$#titles; $i++) {
			my $iter = $listmodel->append();
			# first column = URL, second column = Title, third column = pageobject!!
			if ($key eq 'blog_posts') {
				$listmodel->set($iter,	0 => "$i",
										1 => "$key",
										2 => "$titles[$i]",
										3 => "$dates[$i]",
										4 => "$tags[$i]");
			}
			else {
				$listmodel->set($iter,	0 => "$i",
										1 => "$key",
										2 => "$titles[$i]");
			}
		}
	
	# a treeview to see the data stored in the model
	my $view = Gtk3::TreeView->new($listmodel);
	
	# For displaying the Pages we take a simple TreeView
	my @columns;
	@columns = ('Filename', 'Key', 'Titel', 'Datum', 'Tags') if ($key eq 'blog_posts');
	@columns = ('Filename', 'Key', 'Name/URL') if ($key eq 'blog_lists');
	
	# a cell renderer to render the text for each of the 2 columns
	for (my $i=2; $i <= $#columns; $i++) {
		my $cell = Gtk3::CellRendererText->new();
		
		my $col = Gtk3::TreeViewColumn->new_with_attributes($columns[$i],$cell,'text'=>$i);
		
		$view->append_column($col);
	}
	
	# a TreeSelection Objekt
	# we want to pass to the callback functions the page object of the selected page (= $pages[$i]);
	# whereas $i is the actual selected line (see above)
	my $postobject;
	my $postobject_ref = \$postobject;
	my $key_ref = \$key;
	my $treeselection = $view->get_selection();
	$treeselection->signal_connect('changed'=> sub {
													my ($sel) = @_;
													
													my ($model, $iter) = $sel->get_selected();
													my $i = $model->get_value($iter,0);
													$key = $model->get_value($iter,1);
													$postobject = $blogposts[$i] if ($key eq 'blog_posts');
													$postobject = $bloglists[$i] if ($key eq 'blog_lists');
													});
	
	# THE BUTTONS
	my $new_button = Gtk3::Button->new('New');
	$new_button->signal_connect('clicked'=>\&create_blog_element, [$key_ref, \@blogposts, \@bloglists]);
	
	my @vars = ($key_ref, $postobject_ref);
	my $edit_button = Gtk3::Button->new('Edit');
	$edit_button->signal_connect('clicked' => \&edit_single_blog_element, \@vars);
	
	@vars = ($key_ref, $postobject_ref, \@blogposts);
	my $del_button = Gtk3::Button->new('Delete');
	$del_button->signal_connect('clicked' => \&delete_blog_element, \@vars);
	
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

########################
# CREATE FUNCTIONS
######################
sub create_blog_element {
	my ($widget, $vars_ref) = @_;
	my ($key_ref, $posts_ref, $bloglists_ref) = @$vars_ref;
	my $key = $$key_ref;
	
	if ($key eq 'blog_posts') {
		create_blog_post($posts_ref);
	}
	elsif ($key eq 'blog_lists') {
		create_blog_list($bloglists_ref);
	}
}
	
sub create_blog_post {
	my ($posts_ref) = @_;
	my $content_area = PLog::ContentArea->clean();
	
	my $image = Gtk3::Image->new_from_icon_name('web-browser-symbolic', 'dialog');
	my $header = Gtk3::Label->new();
	$header->set_markup("<b>Create a new Blog Post</b>");
	
	my $title_label = Gtk3::Label->new('Title');
	my $title_buffer = Gtk3::EntryBuffer->new(undef,-1);
	my $title_entry = Gtk3::Entry->new_with_buffer($title_buffer);
	
	my $date_label = Gtk3::Label->new('Date (Format: YYYY-MM-DD hh:mm:ss');
	my $date_buffer = Gtk3::EntryBuffer->new(undef,-1);
	my $date_entry = Gtk3::Entry->new_with_buffer($date_buffer);
	
	my $tags_label = Gtk3::Label->new('Tags Please seperate with a space element (e.g. tag1 tag2)');
	my $tags_buffer = Gtk3::EntryBuffer->new(undef,-1);
	my $tags_entry = Gtk3::Entry->new_with_buffer($tags_buffer);

	my $layout_label = Gtk3::Label->new('Layout File (only Filename)');
	my $layout_buffer = Gtk3::EntryBuffer->new(undef,-1);
	my $layout_entry = Gtk3::Entry->new_with_buffer($layout_buffer);
	
	my @variables = ($posts_ref, $title_buffer, $date_buffer, $tags_buffer, $layout_buffer);
	my $button = Gtk3::Button->new('Create Page');
	$button->signal_connect('clicked' => \&create_post_cb, \@variables);
	
	$content_area->pack_start($image, FALSE, FALSE, 10);
	$content_area->pack_start($header, FALSE, FALSE, 0);
	$content_area->pack_start($title_label, FALSE, FALSE, 0);
	$content_area->pack_start($title_entry, FALSE, FALSE, 0);
	$content_area->pack_start($date_label, FALSE, FALSE, 0);
	$content_area->pack_start($date_entry, FALSE, FALSE, 0);
	$content_area->pack_start($tags_label, FALSE, FALSE, 0);
	$content_area->pack_start($tags_entry, FALSE, FALSE, 0);
	$content_area->pack_start($layout_label, FALSE, FALSE, 0);
	$content_area->pack_start($layout_entry, FALSE, FALSE, 0);
	$content_area->pack_start($button, FALSE, FALSE, 0);
	$content_area->show_all();

}

sub create_post_cb {
	my ($button, $varsref) = @_;
	my @variables = @$varsref;
	
	my $posts_ref = $variables[0];
	#local *blogposts = $posts_ref;
	
	my $title = $variables[1]->get_text();
	my $title_slug = slugify($title);
	my $date = $variables[2]->get_text();
	my $date_raw = $date;
	$date_raw =~ s/\D//g;
	substr($date_raw, 8)='';
	my $tags = $variables[3]->get_text();
	my @tags = split(/\s+/,$tags);
	my $layout = $variables[4]->get_text();
	
	# Get the Filename
	my $projectdirectory = $PLog::siteobject->{'dir'};
	my $postfile = "$projectdirectory/_blog_source/$date_raw\_$title_slug\.textile";
	
	# Add the post object to @PLog::posts
	my $postobject; 
	
	# INITIALIZING
	$postobject->{'filename'} = $postfile;
	$postobject->{'title'} = $title;
	$postobject->{'slug'} = $title_slug;
	$postobject->{'date'} = $date;
	$postobject->{'tags'} = @tags;
	$postobject->{'layout'} = $layout;
	
	# For sorting we need a date_raw key
	# If the user saved a date in the yaml config, take this
	# so that we can sort by date and time!!!
	if ($date) {
		chomp $date;
		# The date has to be saved as follow:
		# YYYY-MM-DD HH:MM:SS
		# we delete all non digits and get: YYYYMMDDHHMMSS
		$date =~ s/\D+//g;
		$postobject->{'date_raw'} = $date
	}
	else {
		my (undef,undef, $filename) = File::Spec->splitpath($postfile);
		# the first 6 digit contains the date in the form YYYYMMDD
		$filename =~ /(\d{8})_(.*)(\.textile)$/;
		my $date_raw = $1;
		$postobject->{'date_raw'} = $date_raw;
	}
	
	# add the post object to @blogposts and sort @blogposts
	push @blogposts, $postobject;
	@blogposts = sort {
					if ($a->{'date_raw'} lt $b->{'date_raw'}) {return 1}
					elsif ($a->{'date_raw'} gt $b->{'date_raw'}) {return -1}
					else {return 0}
					} @blogposts;	
	
	# Create the blog file
	open my $fh, ">:encoding(utf8)", "$postfile";
	my $yaml_lines = Dump($postobject);
	print $fh "$yaml_lines---\n";
	close $fh;
	
	start_module();
}

sub create_blog_list {
	my ($bloglists_ref) = @_;
	
	my $content_area = PLog::ContentArea->clean();
	
	my $image = Gtk3::Image->new_from_icon_name('web-browser-symbolic', 'dialog');
	my $header = Gtk3::Label->new();
	$header->set_markup("<b>Create a new page</b>");
	
	my $name_label = Gtk3::Label->new('Name/URL (relative to /blog/)');
	my $name_buffer = Gtk3::EntryBuffer->new(undef,-1);
	my $name_entry = Gtk3::Entry->new_with_buffer($name_buffer);
	
	my $title_label = Gtk3::Label->new('Title');
	my $title_buffer = Gtk3::EntryBuffer->new(undef,-1);
	my $title_entry = Gtk3::Entry->new_with_buffer($title_buffer);

	my $layout_label = Gtk3::Label->new('Layout File (only Filename)');
	my $layout_buffer = Gtk3::EntryBuffer->new(undef,-1);
	my $layout_entry = Gtk3::Entry->new_with_buffer($layout_buffer);
	
	my @variables = ($bloglists_ref, $name_buffer, $title_buffer, $layout_buffer);
	my $button = Gtk3::Button->new('Create Page');
	$button->signal_connect('clicked' => \&create_bloglist_cb, \@variables);
	
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

sub create_bloglist_cb {
	my ($button, $variables) = @_;
	
	my $name = ${$variables}[1]->get_text();
	my $name_slug = slugify($name);
	my $title = ${$variables}[2]->get_text();
	my $layout = ${$variables}[3]->get_text();
	
	# Create the pagedirectory and pagefile
	my $blog_source = $PLog::siteconf->{'blog_source'};
	$blog_source =~ s/\/$//;
	my $pagedirectory = "$blog_source/$name_slug";
	make_path "$pagedirectory" or die "Could not create the Directory $pagedirectory: $!";
	my $pagefile = "$pagedirectory/index.textile";
	
	# Add the page object to @pages
	my $pageobject;
	
	my $url = File::Spec->abs2rel($pagedirectory, $blog_source);
	
	# the root site shall be shown as "/"
	$url = "/$url";
	
	$pageobject->{'type'} = 'bloglist';
	$pageobject->{'url'} = $url;
	$pageobject->{'title'} = $title;
	$pageobject->{'pagedirectory'} = $pagedirectory;
	$pageobject->{'pagefile'} = $pagefile;
	$pageobject->{'layout'} = $layout;
	
	# this could be important in latter versions!
	# At the moment no importance!
	$pageobject->{'articles'} = undef;
	$pageobject->{'subpage'} = 0;
	
	push @bloglists, $pageobject;
	
	# sort @pages
	@bloglists = sort {
					if ($a->{'url'} lt $b->{'url'}) {return -1}
					elsif ($a->{'url'} gt $b->{'url'}) {return 1}
					else {return 0}
					} @bloglists;
					
	# Create the index.textile file
	open my $fh, ">:encoding(utf8)", "$pagefile";
	my $yaml_lines = Dump($pageobject);
	print $fh "$yaml_lines---\n";
	close $fh;
	
	start_module();
}

########################
# EDIT FUNCTIONS
#######################
sub edit_single_blog_element {
	my ($widget, $vars_ref) = @_;
	my ($key_ref, $postobject_ref) = @$vars_ref;
	my $key = $$key_ref;
	my $postobject = $$postobject_ref;
	
	if ($key eq 'blog_posts') {
		edit_blog_post($postobject);
	}
	elsif ($key eq 'blog_lists') {
		my $filename = $postobject->{'filename'};
		my $name = $postobject->{'url'};
		PLog::UI::Layout::edit_single_layout(undef, [$filename, $name, $postobject]);
	}
}

sub edit_blog_post {
	my ($postobject) = @_;
	
	my $content_area = PLog::ContentArea->clean();
	
	my $postfile = $postobject->{'filename'};
	my $title = $postobject->{'title'} || '';
	
	open my $fh, "<:encoding(utf8)", $postfile or die "Ooops: $!\n";
	
	my (undef, $content) = PLog::Generator->_extract_file_config($fh);
	$content = $content || '';
	
	close $fh;
	
	# TITLE
	my $titlelabel = Gtk3::Label->new('Title');
	my $titlebuffer = Gtk3::EntryBuffer->new("$title",-1);
	my $titleentry = Gtk3::Entry->new_with_buffer($titlebuffer);
	
	
	# PREVIEW
	my $scroll_preview = Gtk3::ScrolledWindow->new();
	my $preview = PLog::UI::Preview->new('content' => $content);
	$scroll_preview->add($preview->{'view'});
	
	
	# EDITOR
	my $textbuffer = Gtk3::TextBuffer->new();
	$textbuffer->set_text($content);
	my @changevariables = ($preview, $textbuffer);
	$textbuffer->signal_connect('changed' => \&edit_buffer_changed, \@changevariables);
	
	my $textview = Gtk3::TextView->new();
	$textview->set_buffer($textbuffer);
	$textview->set_wrap_mode('word');
	
	my $scrolled_window = Gtk3::ScrolledWindow->new();
	$scrolled_window->set_policy('automatic','automatic');
	
	$scrolled_window->add($textview);
	
	# BUTTONS
	my @variables = ($postobject, $titlebuffer, $textbuffer);
	my $save_button = Gtk3::Button->new('Save');
	$save_button->signal_connect('clicked' => \&edit_blog_post_cb, \@variables);
	
	my $cancel_button = Gtk3::Button->new('Cancel');
	$cancel_button->signal_connect('clicked' => sub {start_module();});
	
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

sub edit_buffer_changed {
	my ($button, $varsref) = @_;
	my @variables = @$varsref;
	my $preview = $variables[0];
	my $textbuffer = $variables[1];
	my $start = $textbuffer->get_start_iter;
	my $end = $textbuffer->get_end_iter;
	
	my $content = $textbuffer->get_text($start, $end, TRUE);
	
	$preview->reload($content);
}

sub edit_blog_post_cb {
	my ($button, $varsref) = @_;
	my @variables = @$varsref;
	
	my $postobject = $variables[0];
	my $postfile = $postobject->{'filename'};
	my $titlebuffer = $variables[1];
	my $title = $titlebuffer->get_text;
	$postobject->{'title'} = $title;
	
	my $yaml = Dump($postobject);
	my $textbuffer = $variables[2];
	my $start = $textbuffer->get_start_iter;
	my $end = $textbuffer->get_end_iter;
	my $content = $textbuffer->get_text($start,$end, TRUE);
	
	open my $fh, ">:encoding(utf8)", $postfile or "Could not open file: $! \n";
	print $fh "$yaml---\n" . "$content";
	close $fh;
	
	start_module();
}

########################
# DELETE FUNCTIONS
#######################
sub delete_blog_element {
	my ($widget, $vars_ref) = @_;
	my ($key_ref, $postobject_ref, $posts_ref) = @$vars_ref;
	my $key = $$key_ref;
	
	if ($key eq 'blog_posts') {
		delete_blog_post($postobject_ref, $posts_ref);
	}
	elsif ($key eq 'blog_lists') {
		my $postobject = $$postobject_ref;
		my $filename = $postobject->{'filename'};
		PLog::UI::Layout::delete_layout('bloglist', \$filename);
	}
}

sub delete_blog_post {
	my ($postobject_ref, $posts_ref) = @_;
	my $postobject = $$postobject_ref;
	
	# Really delete?
	my $dialog = Gtk3::Dialog->new();
	$dialog->set_title('Really delete the Page?');
	$dialog->set_transient_for($PLog::window);
	$dialog->set_modal(TRUE);
	$dialog->set_default_size(300,150);
	
	# Add button Yes and No
	$dialog->add_button('Yes','yes');
	$dialog->add_button('No','no');
	
	$dialog->signal_connect('response'=>\&delete_blog_post_cb, [$postobject_ref, $posts_ref]);
	
	# Get the content area of the dialog and add the question
	my $content_area = $dialog->get_content_area();
	my $url = $postobject->{'filename'};
	my $title = $postobject->{'title'};
	my $label = Gtk3::Label->new("Do you really want to delete the Post '$title' (filename: $url)?");
	$label->set_line_wrap(TRUE);
	$content_area->add($label);
	
	$dialog->show_all();
}

sub delete_blog_post_cb {
	my ($dialog, $response_id, $vars_ref) = @_;
	my ($post_ref, $posts_ref) = @$vars_ref;
	my $post = $$post_ref;
	
	#local *blogposts = $posts_ref;
	
	if ($response_id eq 'yes') {
		# Delete the pagedirectory and all files inside
		my $filename = $post->{'filename'};
		print "FILENAME $filename \n";	
		unlink($filename) or die "Could not unlink $filename: $! \n";
	
		# unshift the pageobject from the @PLog::pages object container
		for (my $i=0; $i<=$#blogposts; $i++) {
			# you get the adress of the reference with + 0
			my $post_i_adress = $blogposts[$i] + 0;
			my $post_adress = $post + 0;
			
			if ($post_i_adress == $post_adress) {
				splice @blogposts, $i, 1;
				$i--;
			}
		
		$dialog->destroy();
		}
	}
	else {
		$dialog->destroy();
	}
	
	start_module();
}


#TODO
sub delete_page {
	my ($button, $page_ref) = @_;
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
	
		# unshift the pageobject from the @PLog::pages object container
		#for (my $i=0; $i<=$#PLog::pages; $i++) {
			# you get the adress of the reference with + 0
		#	my $pages_i_adress = $PLog::pages[$i] + 0;
		#	my $page_adress = $page + 0;
		#	
		#	if ($pages_i_adress == $page_adress) {
		#		splice @PLog::pages, $i, 1;
		#		$i--;
		#	}
		
		$dialog->destroy();
		#}
	}
	else {
		$dialog->destroy();
	}
	
	start_module();
}

1;
