#!perl

use Test::Most;

use lib 't/lib';

use SQL::Abstract::Test import => [ qw/ is_same_sql_bind / ];

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

is_same_sql_bind(
    $rs->as_query,
    "( SELECT ${me}.name, RANK() OVER (PARTITION BY fingers ORDER BY hats) AS ranking FROM artist ${me} )",
    [],
    'sql+bind'
);

done_testing;
