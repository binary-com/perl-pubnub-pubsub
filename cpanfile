requires 'Mojolicious', '5.40';
requires 'JSON::MaybeXS';

on configure => sub {
    requires 'ExtUtils::MakeMaker';
};

on build => sub {
    requires 'ExtUtils::MakeMaker';
};

on test => sub {
    requires 'Test::More', '0.96';
};

on develop => sub {
    requires 'Test::Pod', '1.41';
};
