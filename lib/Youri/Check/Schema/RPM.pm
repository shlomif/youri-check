# $Id: Package.pm 1994 2008-06-08 17:34:58Z guillomovitch $
package Youri::Check::Schema::RPM;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('rpms');
__PACKAGE__->add_columns(
    id => {
        data_type         => 'integer',
        is_auto_increment => 1,
    },
    name => {
        data_type         => 'varchar',
        is_auto_increment => 0,
    },
    arch => {
        data_type         => 'varchar',
        is_auto_increment => 0,
    },
    package_id => {
        data_type         => 'integer',
        is_auto_increment => 0,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(
    'package' => 'Youri::Check::Schema::Package', 'package_id'
);

1;
