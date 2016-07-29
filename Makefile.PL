use 5.006000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'PLog',
    VERSION_FROM      => 'lib/PLog.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => { Gtk3 => 0.028}, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/PLog.pm', # retrieve abstract from module
    EXE_FILES	      => ['bin/PLog.pl'],
    AUTHOR            => 'Maximilian Lika <maximilian@(none)>',
    #LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #http://search.cpan.org/perldoc?Module%3A%3ABuild%3A%3AAPI
);
