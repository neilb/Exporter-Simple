use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
print <<EOTEXT;
Exporter::Simple requires PadWalker 0.03 by Robin Houston,
available from http://www.kitsite.com/~robin.

EOTEXT

WriteMakefile(
    'NAME'		=> 'Exporter::Simple',
    'VERSION_FROM'	=> 'lib/Exporter/Simple.pm', # finds $VERSION
    'PREREQ_PM'		=> {
    	Attribute::Handlers => '0.61',
    	PadWalker           => '0.03',
    },
    dist                => {
        # don't ask about existing .tar.gz files
        COMPRESS => 'gzip --force --best'
    },
);
