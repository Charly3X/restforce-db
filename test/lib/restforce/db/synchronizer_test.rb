require_relative "../../../test_helper"

describe Restforce::DB::Synchronizer do

  configure!

  let(:mapping) { Restforce::DB::Mapping.new(name: "Name", example: "Example_Field__c") }
  let(:database_type) { Restforce::DB::RecordTypes::ActiveRecord.new(CustomObject, mapping) }
  let(:salesforce_type) { Restforce::DB::RecordTypes::Salesforce.new("CustomObject__c", mapping) }
  let(:synchronizer) { Restforce::DB::Synchronizer.new(database_type, salesforce_type) }

  describe "#initialize" do
    before { Restforce::DB.last_run = Time.now }
    after { Restforce::DB.last_run = nil }

    it "prefills the Synchronizer's last_run timestamp with the global configuration" do
      expect(synchronizer.last_run).to_equal Restforce::DB.last_run
    end
  end

  describe "#run", vcr: { match_requests_on: [:method, VCR.request_matchers.uri_without_param(:q)] } do
    let(:attributes) do
      {
        name:    "Custom object",
        example: "Some sample text",
      }
    end
    let(:salesforce_id) do
      Salesforce.create!(
        "CustomObject__c",
        mapping.convert(:salesforce, attributes),
      )
    end

    describe "given an existing Salesforce record" do
      before do
        salesforce_id
        synchronizer.run
      end

      it "populates the database with the new record" do
        record = CustomObject.last

        expect(record.name).to_equal attributes[:name]
        expect(record.example).to_equal attributes[:example]
        expect(record.salesforce_id).to_equal salesforce_id
      end
    end

    describe "given an existing database record" do
      let(:database_record) { CustomObject.create!(attributes) }
      let(:salesforce_id) { database_record.reload.salesforce_id }

      before do
        database_record
        synchronizer.run

        Salesforce.records << ["CustomObject__c", salesforce_id]
      end

      it "populates Salesforce with the new record" do
        record = salesforce_type.find(salesforce_id).record

        expect(record.Name).to_equal attributes[:name]
        expect(record.Example_Field__c).to_equal attributes[:example]
      end
    end

    describe "given a Salesforce record with an associated database record" do
      let!(:database_attributes) do
        {
          name:            "Some existing name",
          example:         "Some existing sample text",
          synchronized_at: Time.now,
        }
      end
      let(:database_record) do
        CustomObject.create!(database_attributes.merge(salesforce_id: salesforce_id))
      end

      describe "when synchronization is stale" do
        before do
          # Set the synchronization timestamp to 5 seconds before the Salesforce
          # modification timestamp.
          updated = salesforce_type.find(salesforce_id).last_update
          database_record.update!(synchronized_at: updated - 5)

          synchronizer.run
        end

        it "updates the database record" do
          record = database_record.reload

          expect(record.name).to_equal attributes[:name]
          expect(record.example).to_equal attributes[:example]
        end
      end

      describe "when synchronization is up-to-date" do
        before do
          database_record.touch(:synchronized_at)
          synchronizer.run
        end

        it "does not update the database record" do
          record = database_record.reload

          expect(record.name).to_equal database_attributes[:name]
          expect(record.example).to_equal database_attributes[:example]
        end
      end
    end

  end
end
