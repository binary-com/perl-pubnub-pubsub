requires 'perl', '5.008005';

# requires 'Some::Module', 'VERSION';

requires 'Mojo::IOLoop';

on test => sub {
    requires 'Test::More', '0.96';
};
