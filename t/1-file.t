#!/usr/bin/perl -w
use strict;
use Test::More tests => 17;
use Music::Tag::Test;
use 5.006;

BEGIN { use_ok('Music::Tag') }

my $c = filetest('t/Beethoven/GPL/elise.mp3', 't/Beethoven/GPL/elisetest.mp3', {quiet => 1, verbose =>0},{
	values_in => {
        artist =>, 'Beethoven', 
		album => 'GPL',
		title => 'elisetest',
	},
	skip_write_tests => 0,
	picture_in => 1,
	picture_file => 'beethoven.jpg',
	picture_sha1 => 'b2bf4b2f71bf01e12473dd0ebe295777127589f4',
	picture_read => 1,
	count => 14,
	plugin => 'File'
});
print STDERR "$c test\n";

if ( -e 't/Beethoven/GPL/folder.jpg') {
	unlink 't/Beethoven/GPL/folder.jpg';
}


