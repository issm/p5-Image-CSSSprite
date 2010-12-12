my $m = {
    base => {
        selector => '#navi ul li% a%',
        props => [
            display => 'block',
            width => '160px',
            height => '50px',
        ],
    },

    image_path => '.',

    images => [
        # 1段目
        [
            a1 => '',
            b1 => '',
            c1 => '',
            d1 => '',
            a2 => ['#a1', ':hover'],
            b2 => ['#b1', ':hover'],
            c2 => ['#c1', ':hover'],
            d2 => ['#d1', ':hover'],
        ],

        # 2段目
        [
            e1 => '',
            f1 => '',
            g1 => '',
            h1 => '',
        ],

        # 3段目
        [
            e2 => ['#e1', ':hover'],
            f2 => ['#f1', ':hover'],
            g2 => ['#g1', ':hover'],
            h2 => ['#h1', ':hover'],
        ],
    ],

    options => {},
};
