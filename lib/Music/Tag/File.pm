package Music::Tag::File;
our $VERSION = 0.30;

# Copyright (c) 2007 Edward Allen III. Some rights reserved.

#
# You may distribute under the terms of either the GNU General Public
# License or the Artistic License, as specified in the README file.
#

=pod

=for changes stop

=head1 NAME

Music::Tag::File - Plugin module for Music::Tag to get information from filename and directory entries. 

=for readme stop

=head1 SYNOPSIS

	use Music::Tag

	my $filename = "/var/lib/music/artist/album/track.mp3";

	my $info = Music::Tag->new($filename, { quiet => 1 });

	$info->add_plugin("File");
	$info->get_info();
	   
	# Following prints "artist"
	print "Artist is ", $info->artist;

=for readme continue

=head1 DESCRIPTION

Music::Tag::File is a Music::Tag plugin used to guess information about a music file from its filename, directory name, or contents of the directory it resides in.

This plugin will not overwrite values found by other plugins.

Music::Tag::File objects must be created by Music::Tag.

=begin readme

=head1 INSTALLATION

To install this module type the following:

   perl Makefile.PL
   make
   make test
   make install

=head1 DEPENDENCIES

This module requires these other modules and libraries:

   Music::Tag
   File::Spec

=head1 TEST FILES

Included test files are based on the sample file for Audio::M4P.  For testing only.

=end readme

=for readme stop

=head1 REQUIRED DATA VALUES

No values are required (except filename, which is usually provided on object creation). 

=head1 SET DATA VALUES

=cut

use strict;
use warnings;
use File::Spec;

#use Image::Magick;
our @ISA = qw(Music::Tag::Generic);

=over 4

=item album

Derived from directory file is in.

=item artist

Derived from parent directory of directory file is in.

=item tracknum

Derived from first number(s) found in file name.

=item track

Derived from filename with initial numbers removed.

=item disc

Set to 1 of 1 if no value set.

=item picture

Looks for folder.png, folder.jpg, or cover.jpg

=item lyrics

Looks for file of same name as filename with .txt extension.

=item booklet

Looks for any pdf file.

=cut


sub get_tag {
    my $self     = shift;
    my $filename = $self->info->filename();
    my @dirs     = File::Spec->splitdir( File::Spec->rel2abs($filename) );
    my $fname    = pop @dirs;
    my $dname    = File::Spec->catdir(@dirs);
    my $album    = pop @dirs;
    my $artist   = pop @dirs;

    $album =~ s/_/ /g;
    $album =~ s/\b(\w)/uc($1)/ge;
    $album =~ s/ *$//g;
    $album =~ s/^ *//g;

    if ( length($album) < 2 ) {
        $album = "";
    }

    $artist =~ s/_/ /g;
    $artist =~ s/\b(\w)/uc($1)/ge;
    $artist =~ s/ *$//g;
    $artist =~ s/ *$//g;
    unless ( $self->info->track ) {
        if ( $fname =~ /^[^\d]*(\d+)[^\d]/ ) {
            my $num = sprintf( "%d", $1 );
            $self->info->track($num);
            $self->tagchange("TRACK");
        }
        else {
            $self->info->track(0);
            $self->tagchange("TRACK");
        }
    }
    unless ( $self->info->title ) {
        my $title = $fname;
        $title =~ s/\..+$//g;
        $title =~ s/^\d+\.?\ +//g;
        $title =~ s/^ *//g;
        $title =~ s/ *$//g;
        $self->info->title($title);
        $self->tagchange("TITLE");
    }
    unless ( $self->info->artist ) {
        $self->info->artist($artist);
        $self->tagchange("ARTIST");
    }
    unless ( $self->info->album ) {
        $self->info->album($album);
        $self->tagchange("ALBUM");
    }
    unless ( $self->info->disc ) {
        $self->info->disc("1/1");
        $self->tagchange("DISC");
    }

    if ( ( not $self->info->picture ) or ( $self->options->{coveroverwrite} ) ) {
        my $fname    = File::Spec->catdir($dname, "folder.jpg");
        my $pfname    = File::Spec->catdir($dname, "folder.png");
        my $cfname    = File::Spec->catdir($dname, "cover.jpg");
        if ( -e $fname ) {
            $self->tagchange( "COVER ART", "from folder.jpg" );
            $self->info->picture( $self->_cover_art($fname) );
        }
        elsif ( -e $pfname ) {
            $self->tagchange( "COVER ART", "from folder.png" );
            $self->info->picture( $self->_cover_art($pfname) );
        }
        elsif ( -e $cfname ) {
            $self->tagchange( "COVER ART", "from cover.jpg" );
            $self->info->picture( $self->_cover_art($cfname) );
        }

    }
    if (    ( not $self->info->lyrics )
         or ( $self->options->{lyricsoverwrite} )
         or ( length( $self->info->lyrics ) < 10 ) ) {
        my $fname = $self->info->filename;
        $fname =~ s/\.[^\.]*$/.txt/;
        if ( -e "$fname" ) {
            $self->tagchange( "LYRICS", "from $fname" );
			my $l = $self->_slurp_file($fname);
            $self->info->lyrics($l);
            $l =~ s/\n\r?/ \/ /g;
            $self->tagchange( "LYRICS", substr( $l, 0, 40 ) );
        }
    }
	local *DIR;
	opendir(DIR, $dname);
	while ( my $f = readdir(DIR) ) {
		next if $f =~ /^\./;
        my $fname    = File::Spec->catdir($dname, $f);
		if ($f =~ /\.pdf$/i) {
			unless ($self->info->booklet) {
				$self->tagchange( "BOOKLET", "from $f" );
				$self->info->booklet($f);
			}
		}
		#if ($f =~ /\.txt$/i) {
			#unless ($self->info->lyrics) {
				#$self->tagchange( "LYRICS", "from $fname" );
				#my $l = $self->_slurp_file($fname);
				#$self->info->lyrics($l);
				#$l =~ s/\n\r?/ \/ /g;
				#$self->tagchange( "LYRICS", substr( $l, 0, 40 ) );
				#}
		#}
		if ($f =~ /\.jpg$/i) {
			unless ($self->info->picture) {
				$self->tagchange( "COVER ART", "from $f" );
				$self->info->picture( $self->_cover_art($fname) );
			}
		}
	}



    return $self;
}

sub _slurp_file {
	my $self = shift;
	my $fname = shift;
	local *IN;
	open( IN, $fname ) or return "";
	my $l = "";
	while (<IN>) { $l .= $_ }
	close(IN);
	return $l;
}

sub _cover_art {
    my $self    = shift;
    my $picture = shift;
	my ($vol, $root, $file) = File::Spec->splitpath($picture);
    my $pic = { "Picture Type" => "Cover (front)",
                "MIME type"    => "image/jpg",
                Description    => "",
				filename	   => $file,
                _Data          => "",
              };
    if ( $picture =~ /\.png$/i ) {
        $pic->{"MIME type"} = "image/png";
    }
	return $pic;
    local *IN;
	#unless ( open( IN, $picture ) ) {
	#    $self->error("Could not open $picture for read: $!");
	#    return undef;
	#}
	#my $n = 0;
	#my $b = 1;
	#while ($b) {
	#    $b = sysread( IN, $pic->{"_Data"}, 1024, $n );
	#    $n += $b;
	#}
	#close(IN);
	#return $pic;
}

sub save_cover {
    my $self = shift;
    my ( $vol, $dir, $file ) = File::Spec->splitpath( $self->info->filename );
    my $filename = File::Spec->catpath( $vol, $dir, "folder.jpg" );

    #if ($dname eq "/") { $dname = "" } else {$dname = File::Spec->catpath($vol, $dir) }
    my $art = $self->info->picture;
    if ( exists $art->{_Data} ) {
        local *OUT;
        if ( $art->{"MIME type"} eq "image/png" ) {
            $filename = File::Spec->catpath( $vol, $dir, "folder.png" );
        }
        elsif ( $art->{"MIME type"} eq "image/bmp" ) {
            $filename = File::Spec->catpath( $vol, $dir, "folder.jpg" );
        }
        $self->status("Saving cover image to $filename");
        unless ( open OUT, ">$filename" ) {
            $self->status("Error writing to $filename: $!, skipping.");
            return undef;
        }
        my $b = 0;
        my $l = length( $art->{_Data} );
        while ( $b < $l ) {
            my $s = syswrite OUT, $art->{_Data}, 1024, $b;
            if ( defined $s ) {
                $b += $s;
            }
            else {
                $self->status("Error writing to $filename: $!, skipping.");
                return undef;
            }
        }
        close OUT;
    }
    return 1;
}

sub save_lyrics {
    my $self  = shift;
    my $fname = $self->info->filename;
    $fname =~ s/\.[^\.]*$/.txt/;
    my $lyrics = $self->info->lyrics;
    if ($lyrics) {
        local *OUT;
        $self->status("Saving lyrics image to $fname");
        unless ( open OUT, ">$fname" ) {
            $self->status("Error writing to $fname: $!, skipping.");
            return undef;
        }
        print OUT $lyrics;
        close OUT;
    }
    return 1;
}

sub set_tag {
    my $self = shift;
	unless ( $self->options("no_savecover")) {
		$self->save_cover( $self->info );
	}
    unless ( $self->options("no_savelyrics") or $self->info->filename =~ /\.mp3$/i ) {
        $self->save_lyrics( $self->info );
    }
    return $self;
}

sub default_options {
	{
		lyricsoverwrite => 0,
		coveroverwrite => 0,
		no_savecover => 0,
		no_savelyrics => 0,
	}
}

=back

=head1 OPTIONS

=over 4

=item lyricsoverwrite

If true will overwrite lyrics with values found by plugin.

=item coveroverwrite

If true will overwrite picture with values found by plugin.

=item no_savelyrics

If true will not save lyrics.

=item no_savecover

If true will not save cover.

=back

=head1 METHODS

=over

=item default_options

Returns the default options for the plugin.  

=item set_tag

Saves info such as image files, lyrics, etc. Note: Currently calls save_lyrics method for all files that do not end in .mp3 unless np_savelyrics is set.

=item get_tag

Gathers info from file name, text files, etc.

=item save_lyrics

Save lyrics to a text file. 

=item save_cover

Save cover picture to disk. 

=back

=head1 BUGS

This method of determining information about a music file is always unreliable unless great care is taken in file naming.

=head1 SEE ALSO

L<Music::Tag>

=head1 CHANGES

=for changes continue

=over 4

=item Release Name: 0.30

=over 4

=item *

Changed license to allow option of GPL

=item *

Started using Pod::Readme

=back

=begin changes

=item Release Name: 0.29

=over 4

=item * 

Kwalitee Changes

=item * 

Added no_savecover and no_savelyrics

=back

=item Release Name: 0.28

=over 4

=item * Split off from Music::Tag distribution

=back

=end changes

=back

=for changes stop

=for readme continue

=head1 AUTHOR 

Edward Allen III <ealleniii _at_ cpan _dot_ org>

=head1 COPYRIGHT

Copyright (c) 2007 Edward Allen III. Some rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either:

a) the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

b) the "Artistic License" which comes with Perl.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
the GNU General Public License or the Artistic License for more details.

You should have received a copy of the Artistic License with this
Kit, in the file named "Artistic".  If not, I'll be glad to provide one.

You should also have received a copy of the GNU General Public License
along with this program in the file named "Copying". If not, write to the
Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
Boston, MA 02110-1301, USA or visit their web page on the Internet at
http://www.gnu.org/copyleft/gpl.html.

=cut

1;

