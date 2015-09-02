#-- encoding: UTF-8
#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2015 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

require_relative 'db_worker'

module Migration
  module LegacyYamler
    ##
    # Migrate the given serialized YAML column from Syck to Psych
    # (if any).
    def migrate_to_psych(table, column)
      table_name = ActiveRecord::Base.connection.quote_table_name(table)
      column_name = ActiveRecord::Base.connection.quote_column_name(column)

      fetch_data(table_name, column_name).each do |row|
        transformed = ::Psych.dump(load_with_sych(row[column]))

        ActiveRecord::Base.connection.execute <<-SQL
          UPDATE #{table_name}
          SET #{column_name} = #{ActiveRecord::Base.connection.quote(transformed)}
          WHERE id = #{row['id']};
        SQL
      end
    end

    ##
    # Tries to load syck and fails with an error
    # if it was not installed.
    # To continue with the affected migrations, install syck with `bundle install --with syck`
    def load_with_syck(yaml)
      @@syck ||= load_syck
      @@syck.load(yaml)
    end

    private

    def fetch_data(table_name, column_name)
      ActiveRecord::Base.connection.select_all <<-SQL
        SELECT id, #{column_name}
        FROM #{table_name}
        WHERE #{column_name} LIKE '---%'
      SQL
    end

    def load_syck
      require 'syck'
      ::Syck
    rescue LoadError => e
      abort = -> (str) { abort("\e[31m#{str}\e[0m") }
      abort.call <<-WARN
      It appears you have existing serialized YAML in your database.

      This YAML may have been serialized with Syck, which allowed to parse YAML
      that is now considered invalid given the default Ruby YAML parser (Psych),
      we need to convert that YAML to be Psych-compatible.

      Use `bundle install --with syck` to install the syck YAML parser
      and re-run the migrations.
      WARN

      raise e
    end
  end
end
