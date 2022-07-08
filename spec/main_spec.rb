require "spec_helper"
require_relative "../main"

describe "#main" do
  before(:each) do
    stub_const("POSTCODE", "SW1A 1AA")
    stub_const("EXPORT_MPAN", "123456789")
    stub_const("METER_SN", "123456789")
    stub_const("OCTOPUS_API_KEY", "sk_test_123456789")

    @client = Faraday.new()
    @totals = {
      "2018-05-16" => 33.39,
    }

    stub_octopus_api_requests
  end

  def stub_octopus_api_requests
    stub_request(
      :get,
      "https://api.octopus.energy/v1/industry/grid-supply-points/"
    ).with(
      query: { postcode: "SW1A 1AA" }
    ).to_return(
      status: 200,
      body: {
        "count": 1,
        "next": nil,
        "previous": nil,
        "results": [
          {
            "group_id": "_A"
          },
        ]
      }.to_json
    )

    stub_request(
      :get,
      "https://api.octopus.energy/v1/products/AGILE-OUTGOING-19-05-13/electricity-tariffs/E-1R-AGILE-OUTGOING-19-05-13-A/standard-unit-rates/"
    ).with(
      query: { page_size: 1500, period_from: "2018-05-16T22:00:00Z", period_to: "2018-05-16T23:00:00Z" }
    ).to_return(
      status: 200,
      body: {
        "count": 2,
        "next": nil,
        "previous": nil,
        "results": [
          {
            "value_exc_vat": 11.55,
            "value_inc_vat": 11.55,
            "valid_from": "2018-05-16T22:30:00Z",
            "valid_to": "2018-05-16T23:00:00Z"
          },
          {
            "value_exc_vat": 11.13,
            "value_inc_vat": 11.13,
            "valid_from": "2018-05-16T22:00:00Z",
            "valid_to": "2018-05-16T22:30:00Z"
          },
        ]
      }.to_json
    )
  end

  describe "#find_export_tariff_geo" do
    it "returns the correct group_id for a postcode" do
      expect(find_export_tariff_geo).to eq("E-1R-AGILE-OUTGOING-19-05-13-A")
    end
  end

  describe "#calculate_payment_per_kwh" do
    it "returns the correct payment per kwh" do
      start = from = "2018-05-16T22:00:00Z"
      to = "2018-05-16T23:00:00Z"

      result = calculate_payment_per_kwh(3, start, from, to)

      expect(result).to eq(33.39)
    end
  end
end
