use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'		=> 'Exporter::Simple',
    'VERSION_FROM'	=> 'lib/Exporter/Simple.pm', # finds $VERSION
    'PREREQ_PM'		=> {
    	Attribute::Handlers => '0.61',
        Filter::Simple      => '0.77',
    	PadWalker           => '0.03',
    },
    dist                => {
        # don't ask about existing .tar.gz files
        COMPRESS => 'gzip --force --best'
    },
);
