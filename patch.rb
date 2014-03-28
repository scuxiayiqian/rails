# Activate the gem you are reporting the issue against.
require 'active_record'
require 'minitest/autorun'
require 'logger'
 
# Ensure backward compatibility with Minitest 4
Minitest::Test = MiniTest::Unit::TestCase unless defined?(Minitest::Test)
 
# This connection will do for database-independent bug reports.
ActiveRecord::Base.establish_connection(adapter: 'postgresql', database: 'test123')
ActiveRecord::Base.logger = Logger.new(STDOUT)
 
ActiveRecord::Schema.define do
 
  execute <<_SQL
  DROP TABLE IF EXISTS postgresql_numeric_domains;
  DROP DOMAIN IF EXISTS custom_money;
  CREATE DOMAIN custom_money as numeric(8,2);
  CREATE TABLE postgresql_numeric_domains (
    id SERIAL PRIMARY KEY,
  amount numeric(8,2),
  custom_amount custom_money
  );
_SQL
 
end
 
 
module CustomMoneyDomainPatch
  def simplified_type(field_type)
    if field_type == "custom_money"
      :decimal
    else
      super
    end
  end
end
 
ActiveRecord::ConnectionAdapters::PostgreSQLColumn.send :include, CustomMoneyDomainPatch
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::OID.tap do |klass|
  klass.register_type('custom_money', klass::Decimal.new)
end
ActiveRecord::Base.connection.send :reload_type_map
 
class PostgresqlNumericDomain < ActiveRecord::Base
end
 
class BugTest < Minitest::Unit::TestCase
 
  def teardown
    [PostgresqlNumericDomain].each(&:delete_all)
  end
 
  # works, not using domain
  def test_numeric
    d = PostgresqlNumericDomain.new(amount: '')
    assert_equal({}, d.changes)
    d.save!
    assert_equal nil, d.amount
    assert_equal nil, d.custom_amount
  end
 
  # Currently fails, using domain
  def test_numeric_domain
    d = PostgresqlNumericDomain.new(custom_amount: '')
    assert_equal({}, d.changes)
    d.save!
    assert_equal nil, d.amount
    assert_equal nil, d.custom_amount
  end
end