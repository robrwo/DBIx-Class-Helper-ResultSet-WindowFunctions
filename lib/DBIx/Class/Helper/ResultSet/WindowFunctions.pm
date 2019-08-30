package DBIx::Class::Helper::ResultSet::WindowFunctions;

# ABSTRACT: Add support for window functions to DBIx::Class

use v5.10;

use strict;
use warnings;

use parent 'DBIx::Class::ResultSet';

our $VERSION = 'v0.2.1';

=head1 SYNOPSIS

In a resultset:

  package MyApp::Schema::ResultSet::Wobbles;

  use base qw/DBIx::Class::ResultSet/;

  __PACKAGE__->load_components( qw/
      Helper::ResultSet::WindowFunctions
  /);

Using the resultset:

  my $rs = $schema->resultset('Wobbles')->search_rs(
    undef,
    {
      '+select' => {
          avg   => 'fingers',
          -over => {
              partition_by => 'hats',
              order_by     => 'age',
          },
      },
      '+as' => 'avg',
    }
  );

=head1 DESCRIPTION

This helper adds rudimentary support for window functions to
L<DBIx::Class> resultsets.

=head1 CAVEATS

This module is experimental.

Not all databases support window functions.

=cut

sub _resolved_attrs {
    my $rs    = $_[0];
    my $attrs = $rs->{attrs};

    my $sqla = $rs->result_source->storage->sql_maker;

    foreach my $attr (qw/ select +select /) {

        my $sel = $attrs->{$attr} or next;
        my @sel;

        foreach my $col ( @{ ref $sel eq 'ARRAY' ? $sel : [$sel] } ) {

            push @sel, $col;

            next unless ref $col eq 'HASH';

            my $as = delete $col->{'-as'};
            my $over = delete $col->{'-over'} or next;

            $rs->throw_exception('-over must be a hashref')
              unless ref $over eq 'HASH';

            my ( $sql, @bind ) = $sqla->_recurse_fields($col);

            my ( $part_sql, @part_bind ) =
              $sqla->_recurse_fields( $over->{partition_by} );
            if ($part_sql) {
                $part_sql = $sqla->_sqlcase('partition by ') . $part_sql;
            }

            my ( $order_sql, @order_bind ) =
              $sqla->_order_by( $over->{order_by} );

            $sql .= $sqla->_sqlcase(' over (') . $part_sql . $order_sql . ')';
            if ($as) {
                $sql .= $sqla->_sqlcase(' as ') . $sqla->_quote($as);
            }

            push @bind, @part_bind, @order_bind;

            $sel[-1] = \[ $sql, @bind ];

        }

        $attrs->{$attr} = \@sel;

    }

    return $rs->next::method;
}

=head1 SEE ALSO

L<DBIx::Class>

=cut

1;
