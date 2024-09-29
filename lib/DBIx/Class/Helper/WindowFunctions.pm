package DBIx::Class::Helper::WindowFunctions;

# ABSTRACT: Add support for window functions and aggregate filters to DBIx::Class

use v5.20;
use warnings;

use parent 'DBIx::Class::ResultSet';

use Ref::Util qw/ is_plain_arrayref is_plain_hashref /;

# RECOMMEND PREREQ: Ref::Util::XS

use namespace::clean;

use experimental qw/ postderef signatures /;

our $VERSION = 'v0.7.0';

=head1 SYNOPSIS

In a resultset:

  package MyApp::Schema::ResultSet::Wobbles;

  use base qw/DBIx::Class::ResultSet/;

  __PACKAGE__->load_components( qw/
      Helper::WindowFunctions
  /);

Using the resultset:

  my $rs = $schema->resultset('Wobbles')->search_rs(
    undef,
    {
      '+select' => {
          avg     => 'fingers',
          -filter => { hats => { '>', 1 } },
          -over   => {
              partition_by => 'hats',
              order_by     => 'age',
          },
      },
      '+as' => 'avg',
    }
  );

=head1 DESCRIPTION

This helper adds rudimentary support for window functions and aggregate filters to
L<DBIx::Class> resultsets.

It adds the following keys to the resultset attributes:

=head2 -over

This is used for window functions, e.g. the following adds a row number columns

  '+select' => {
      row_number => [],
      -over => {
         partition_by => 'class',
         order_by     => 'score',
      },
  },

which is equivalent to the SQL

  ROW_NUMBER() OVER ( PARTITION BY class ORDER BY score )

You can omit either the C<partition_by> or C<order_by> clauses.

=head2 -filter

This is used for filtering aggregate functions or window functions, e.g. the following clause

  '+select' => {
      count     => \ 1,
      -filter => { kittens => { '<', 10 } },
  },

is equivalent to the SQL

  COUNT(1) FILTER ( WHERE kittens < 10 )

You can apply filters to window functions, e.g.

  '+select' => {
      row_number => [],
      -filter => { class => { -like => 'A%' } },
      -over => {
         partition_by => 'class',
         order_by     => 'score',
      },
  },

which is equivalent to the SQL

  ROW_NUMBER() FILTER ( WHERE class like 'A%' ) OVER ( PARTITION BY class ORDER BY score )

The C<-filter> feature was added v0.6.0.

=head1 CAVEATS

This module is experimental.

Not all databases support window functions.

=cut

sub _resolved_attrs ($rs) {
    my $attrs = $rs->{attrs};

    my $sqla = $rs->result_source->storage->sql_maker;

    foreach my $attr (qw/ select +select /) {

        my $sel = $attrs->{$attr} or next;
        my @sel;

        foreach my $col ( is_plain_arrayref($sel) ? $sel->@* : $sel ) {

            push @sel, $col;

            next unless is_plain_hashref($col);

            my $as = delete $col->{'-as'};
            my $over = delete $col->{'-over'};
            my $filter = delete $col->{'-filter'};

            next unless $over || $filter;

            my ( $sql, @bind ) = $sqla->_recurse_fields($col);

            if ($over) {

                $rs->throw_exception('-over must be a hashref')
                  unless is_plain_hashref($over);

                my ( $part_sql, @part_bind ) =
                  $sqla->_recurse_fields( $over->{partition_by} );
                if ($part_sql) {
                    $part_sql = $sqla->_sqlcase('partition by ') . $part_sql;
                }

                my @filter_bind;
                if ( defined $filter ) {
                    $rs->throw_exception('-filter must be an arrayref or hashref')
                      unless is_plain_arrayref($filter)
                      or is_plain_hashref($filter);
                    @filter_bind = $sqla->_recurse_where($filter);
                    my $clause = shift @filter_bind;
                    $sql .= $sqla->_sqlcase(' filter (where ') . $clause . ')';
                }

                my ( $order_sql, @order_bind ) =
                  $sqla->_order_by( $over->{order_by} );

                $sql .= $sqla->_sqlcase(' over (') . $part_sql . $order_sql . ')';
                if ($as) {
                    $sql .= $sqla->_sqlcase(' as ') . $sqla->_quote($as);
                }

                push @bind, @part_bind, @filter_bind, @order_bind;

            }
            else {

                $rs->throw_exception('-filter must be an arrayref or hashref')
                  unless is_plain_arrayref($filter)
                  or is_plain_hashref($filter);
                my @filter_bind = $sqla->_recurse_where($filter);
                my $clause      = shift @filter_bind;
                $sql .= $sqla->_sqlcase(' filter (where ') . $clause . ')';

                push @bind, @filter_bind;

            }

            $sel[-1] = \[ $sql, @bind ];

        }

        $attrs->{$attr} = \@sel;

    }

    return $rs->next::method;
}

=head1 SUPPORT FOR OLDER PERL VERSIONS

Since v0.7.0, the this module requires Perl v5.20 or later.

Future releases may only support Perl versions released in the last ten years.

=head1 SEE ALSO

L<DBIx::Class>

=cut

1;
