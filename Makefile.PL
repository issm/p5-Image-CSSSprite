use inc::Module::Install;
name 'Image-CSSSprite';
all_from 'lib/Image/CSSSprite.pm';

requires 'File::Basename';
requires 'Class::Accessor::Lite';
requires 'Image::Imlib2';
requires 'Image::Size';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
