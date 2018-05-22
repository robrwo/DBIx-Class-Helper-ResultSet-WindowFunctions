#!perl

use Test::Most;

use lib 't/lib';

use Test::Schema;

my $schema = Test::Schema->deploy_or_connect('dbi:SQLite::memory:');

my $rs = $schema->resultset('Artist')->search_rs(
    undef,
    {
        columns   => [qw/ name /],
        '+select' => {
            rank  => [],
            -as => 'ranking',
            -over      => {
                partition_by => 'fingers',
                order_by     => 'hats',
            },
        },
    }
);

my $me = $rs->current_source_alias;

my ( $sql, @bind ) = @{ ${ $rs->as_query } };

like $sql, qr/^\(SELECT ${me}\.name, RANK\(\s*\) OVER \(PARTITION BY fingers ORDER BY hats\) AS ranking FROM artist ${me}\)$/, 'SQL';

is_deeply( \@bind, [], 'bind params' )
    or diag(explain \@bind);

done_testing;
