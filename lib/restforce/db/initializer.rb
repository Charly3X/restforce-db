module Restforce

  module DB

    # Restforce::DB::Initializer is responsible for ensuring that both systems
    # are populated with the same records at the root level. It iterates through
    # recently added or updated records in each system for a mapping, and
    # creates a matching record in the other system, when necessary.
    class Initializer < Task

      # Public: Run the initialization loop for this mapping.
      #
      # Returns nothing.
      def run(*_)
        return if @mapping.strategy.passive?

        @runner.run(@mapping) do |run|
          run.salesforce_instances.each { |instance| create_in_database(instance) }
          run.database_instances.each { |instance| create_in_salesforce(instance) }
        end
      end

      private

      # Internal: Attempt to create a partner record in the database for the
      # passed Salesforce record. Does nothing if the Salesforce record has
      # already been synchronized into the system at least once.
      #
      # instance - A Restforce::DB::Instances::Salesforce.
      #
      # Returns nothing.
      def create_in_database(instance)
        return unless @mapping.strategy.build?(instance)

        created = @mapping.database_record_type.create!(instance)

        @runner.cache_timestamp instance
        @runner.cache_timestamp created
      rescue ActiveRecord::ActiveRecordError, Faraday::Error::ClientError => e
        DB.logger.error(SynchronizationError.new(e, instance))
      end

      # Internal: Attempt to create a partner record in Salesforce for the
      # passed database record. Does nothing if the database record already has
      # an associated Salesforce record.
      #
      # instance - A Restforce::DB::Instances::ActiveRecord.
      #
      # Returns nothing.
      def create_in_salesforce(instance)
        return if instance.synced?

        created = @mapping.salesforce_record_type.create!(instance)

        @runner.cache_timestamp instance
        @runner.cache_timestamp created
      rescue Faraday::Error::ClientError => e
        DB.logger.error(SynchronizationError.new(e, instance))
      end

    end

  end

end
