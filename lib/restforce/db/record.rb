module Restforce

  module DB

    # Public: Restforce::DB::Record is an abstraction for a two-way binding
    # between an ActiveRecord class and a Salesforce object type. It provides an
    # interface for mapping database columns to Salesforce fields.
    class Record

      # Public: Initialize a Restforce::DB::Model.
      #
      # db_model         - A Class compatible with ActiveRecord::Base.
      # salesforce_model - A String name of an object type in Salesforce.
      def initialize(db_model, salesforce_model, **mappings)
        @mapping = Mapping.new(mappings)
        @database_model = RecordTypes::ActiveRecord.new(db_model, @mapping)
        @salesforce_model = RecordTypes::Salesforce.new(salesforce_model, @mapping)
      end

      # Public: Append the passed mappings to this model.
      #
      # mappings - A Hash of database column names mapped to Salesforce fields.
      #
      # Returns nothing.
      def add_mappings(mappings)
        @mapping.add_mappings mappings
      end

    end

  end

end