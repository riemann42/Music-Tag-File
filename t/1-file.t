#!/usr/bin/perl -w
use strict;

use Test::More tests => 7;
use 5.006;

BEGIN { use_ok('Music::Tag') }

our $options = {};

my $file        = "t/Beethoven/GPL/elise.mp3";

SKIP: {
	skip "File: $file does not exists", 7 unless ( -f $file );
	return unless ( -f $file );
	my $tag = Music::Tag->new( $file, {}, 'File' );
	ok( $tag, 'Object created: ' . $file );
	die unless $tag;
	ok( $tag->get_tag, 'get_tag called: ' . $file );
	ok( $tag->isa('Music::Tag'), 'Correct Class: ' . $file );
	is( $tag->artist, "Beethoven", 'Artist: ' . $file );
	is( $tag->album,  "GPL",       'Album: ' . $file );
	is( $tag->title,  "elise",     'Title: ' . $file );
	$tag->close();
	$tag = undef;
}


