#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "${FindBin::Bin}/../lib";
use Image::CSSSprite;
use Data::Dumper;
use Try::Tiny;
use opts;


my ($target, $manifest, $img_out, $css_out);

try {
    opts
        $target   => { isa => 'Str', required => 1 },
            $manifest => { isa => 'Str' },
                $img_out  => { isa => 'Str', alias => 'img|image' },
                    $css_out  => { isa => 'Str', alias => 'css' },
    ;
} catch {
    usage(shift);
    exit 1;
};


sub usage {
    chomp( my $msg = shift || '' );
    my $__FILE__ = __FILE__;

    print << "    ...";
Error:
    $msg

Usage:
    #
    $__FILE__ --target /path/to/imgs

    #
    $__FILE__ --target /path/to/imgs --manifest /path/to/manifest.pl

    #
    $__FILE__ --target /path/to/imgs --img /path/to/csssprited.png --css /path/to/csssprited.css

Options:
    ...
}



sub main {
    my $csssp = Image::CSSSprite->new({
        target   => $target,
        manifest => $manifest,
        img_out  => $img_out,
        css_out  => $css_out,
    });
    $csssp->manifest_from_script;
    $csssp->scan_images;
    print $csssp->css;
    $csssp->save;
}




main();
__END__
