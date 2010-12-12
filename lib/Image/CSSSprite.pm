package Image::CSSSprite;
use 5.008.009;
use strict;
use warnings;
our $VERSION = '0.01';

use File::Basename;
use Image::Size;
use Image::Imlib2;

use Class::Accessor::Lite (
    new => 1,
    rw  => [qw/target manifest img_out css_out
               _manifest _sprite_width _sprite_height
               _img_buff _css_buff

               image css
              /],
);

my $img_basename_default = 'csssprite.png';
my $css_basename_default = 'csssprite.css';

my @img_ext = qw/png jpg jpeg gif/;


sub manifest_from_script {
    my $self = shift;
    unless (defined $self->manifest) {
        (my $m = sprintf '%s/_manifest.pl', $self->target) =~ s{//+}{/}g;
        $self->manifest($m);
    }

    my $manifest = do $self->manifest  or die $!;
    $self->_manifest($manifest);
}


sub scan_images {
    my $self = shift;
    my $manifest = $self->_manifest;

    my ($sprite_width, $sprite_height) = (0, 0);
    my (@img_buff, @css_buff);

    my ($x_tl, $y_tl) = (0, 0);  # 現在の左上座標

    for my $l (@{ $manifest->{images} }) {
        next  if ref($l) ne 'ARRAY';

        $x_tl = 0;

        my $w_in_l  = 0;  # 段中の各画像の幅の合計
        my $h_l_max = 0;  # 段中の各画像で，高さが最大のもの

        while (1) {
            my ($pre, $sel) = (shift @$l, shift @$l);
            last  unless defined $pre;

            $sel = [ $sel ]  if ref($sel) eq '';
            $sel->[0] ||= "#${pre}";

            my $f = $self->_check_imagefile($pre)
                or die "No such image: $pre.{png|jpg|jpeg|gif}";

            my ($w, $h) = imgsize($f);

            # buffer img
            my $img = Image::Imlib2->load($f);
            push @img_buff, +{ img => $img, x => $x_tl, y => $y_tl, w => $w, h => $h };

            # buffer css
            push @css_buff, $self->_cssize($pre, $sel, $w, $h,  -$w_in_l, -$sprite_height);

            $w_in_l += $w;
            $h_l_max = $h  if $h > $h_l_max;

            $x_tl += $w;
        }

        $sprite_width = $w_in_l  if $w_in_l > $sprite_width;  # 段での画像幅の合計が最大となるように
        $sprite_height += $h_l_max;

        $y_tl += $h_l_max;
    }

    $self->_img_buff(\@img_buff);
    $self->_css_buff(\@css_buff);

    $self->_sprite_width($sprite_width);
    $self->_sprite_height($sprite_height);


    $self->_concat_images;
    $self->_generate_css;


    [$sprite_width, $sprite_height];
}


sub _check_imagefile {
    my ($self, $pre) = @_;
    my ($f) = grep -f $_,map $self->target . "/${pre}." . $_, @img_ext;
    return $f;
}


sub _cssize {
    my ($self, $pre, $sel, $w, $h, $pos_l, $pos_t) = @_;
    my $manifest = $self->_manifest;
    my $selector = $sel;
    my $css   = '';
    my @props = ();

    # 画像URL定義を共有するタイプ
    if (defined $manifest->{base}) {
        my $base = $manifest->{base};
        if (defined $base->{selector}) {
            # my $s = $selector;
            # ($selector = $base->{selector}) =~ s/%/$s/;
            my @s = map $_, @$sel;
            $selector = $base->{selector};
            do { 1 } while ( $selector =~ s/%/ shift(@s) || '' /ex );
        }
    }
    # 画像URL定義をそれぞれ行うタイプ
    else {
        $selector = join '', @$sel;

        push @props, "width: ${w}px;", "height: ${h}px;";
        push @props, sprintf(
            'background-image: url(%s);',
            $self->_image_url,
        );
    }

    push @props, sprintf(
        'background-position: %dpx %dpx;',
        $pos_l, $pos_t,
    );


    $css = sprintf(
        '%s { %s }',
        $selector,
        join(' ', @props),
    );

    return $css;
}


sub _image_url {
    my $self = shift;
    my $img_basename = basename ($self->img_out || $img_basename_default);
    my $img_path = $self->_manifest->{image_path} || '';
    $img_path .= '/'  if $img_path  &&  $img_path !~ m{/$};

    return $img_path . $img_basename;
}




sub _concat_images {
    my $self = shift;
    my $img_buff = $self->_img_buff;

    my $img_sprite = Image::Imlib2->new( $self->_sprite_width, $self->_sprite_height );

    for my $i (@$img_buff) {
        $img_sprite->blend(
            $i->{img},
            1,
            0, 0,
            $i->{w}, $i->{h},
            $i->{x}, $i->{y},
            $i->{w}, $i->{h},
        );
    }

    $self->image($img_sprite);
}



sub _generate_css {
    my $self = shift;
    my $manifest = $self->_manifest;

    my $css_buff = $self->_css_buff;

    # 画像URL定義共有タイプ
    if ( defined $manifest->{base}  &&  defined $manifest->{base}{selector} ) {
        my $base = $manifest->{base};
        (my $selector = $base->{selector}) =~ s/%//g;

        my @props = ();
        push @props, sprintf 'background-image: url(%s);', $self->_image_url;

        my $props_base = $base->{properties} || $base->{props};
        if (defined $props_base  &&  ref($props_base) eq 'ARRAY') {
            while (1) {
                my ($k, $v) = (shift @$props_base, shift @$props_base);
                last  unless defined $k;

                push @props, "$k: $v;";
            }
        }


        my $css = sprintf(
            "%s {\n  %s\n}",
            $selector,
            join("\n  ", @props),
        );

        unshift @$css_buff, $css;
        $self->_css_buff($css_buff);
    }

    my $css_generated = join("\n", @$css_buff) . "\n";
    $self->css($css_generated);
}




sub save {
    my $self = shift;
    $self->save_image;
    $self->save_css;
    return;
}


sub save_image {
    my $self = shift;
    (my $target = $self->target) =~ s{/+$}{};

    my $img_out = $self->img_out;
    unless (defined $img_out) {
        $img_out = "${target}/${img_basename_default}";
    }

    $self->image->save($img_out);
}


sub save_css {
    my $self = shift;
    (my $target = $self->target) =~ s{/+$}{};

    my $css_out = $self->css_out;
    unless (defined $css_out) {
        $css_out = "${target}/${css_basename_default}";
    }

    open my $fh, '>', $css_out  or  die $!;
    print $fh $self->css;
    close $fh;
    return ;
}




1;
__END__

=head1 NAME

Image::CSSSprite -

=head1 SYNOPSIS

  use Image::CSSSprite;

=head1 DESCRIPTION

Image::CSSSprite is

=head1 CONSTRUCTOR

$csssp = Image::CSSSprite->new(\%params);

=over 4

=item target

directory path that contains images to css-sprite.

=item manifest

how

=item img_out

Path of image file css-sprited. Default is set to "./csssprite.png".

=item css_out

Path of CSS file. Default is set to "./csssprite.css".

=back

=head1 METHODS

=over 4

=item read_from_manifest

=item scan_images

=item _concat_images

Returns Image::Imlib2 object.

=item _generate_css


=item save

Saves css-sprited image and css.

=item save_image

Saves css-sprited image.

=item save_css

Saves css-sprited css.

=back

=head1 AUTHOR

issm E<lt>issmxx@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
