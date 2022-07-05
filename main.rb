require "json"
require "faraday"

BASE_URL = "https://api.octopus.energy/v1"
EXPORT_TARRIF = "AGILE-OUTGOING-19-05-13"
EXPORT_TARRIF_GEO = "E-1R-#{EXPORT_TARRIF}-J"
EXPORT_MPAN = ENV["OCTOPUS_EXPORT_MPAN"]
METER_SN = ENV["OCTOPUS_ELECTRICITY_METER_SN"]

@totals = Hash.new(0)
@client = Faraday.new do |f|
  f.request :authorization, :basic, ENV["OCTOPUS_API_KEY"], ""
end

def query_export_prices(from, to)
  prices_response = @client.get(
    "#{BASE_URL}/products/#{EXPORT_TARRIF}/electricity-tariffs/#{EXPORT_TARRIF_GEO}/standard-unit-rates/",
      {
        period_from: from,
        period_to: to
      }
  )
  JSON.parse(prices_response.body)["results"]
end

def query_generated_electricity(from, to)
  generation_response = @client.get(
    "#{BASE_URL}/electricity-meter-points/#{EXPORT_MPAN}/meters/#{METER_SN}/consumption/",
    {
      page_size: 48, # 24 hours of half-hourly readings.
      period_from: from,
      period_to: to
    }
  )
  generated_electricity = JSON.parse(generation_response.body)["results"]
end

def calculate_payment_per_kwh(export, start, from, to)
  result = query_export_prices(from, to).select { |price| price["valid_from"] == start }.first
  return 0 if result.nil?

  export * result["value_exc_vat"]
end

# TODO(issyl0): Make these dates configurable.
from = "2022-07-04T00:01Z"
to = "2022-07-04T23:59Z"

query_generated_electricity(from, to).each do |result|
  next if result["consumption"].zero?

  export = result["consumption"]
  start = DateTime.parse(result["interval_start"]).strftime("%Y-%m-%dT%H:%M:%SZ")
  payment_per_kwh = calculate_payment_per_kwh(export, start, from, to)

  puts "Exported #{export} kW at #{start}, earning #{payment_per_kwh.round(2)}p."

  @totals[from] += payment_per_kwh
end

puts "Total for #{from.split("T").first} to #{to.split("T").first}: #{@totals[from].round(2)}p, or £#{(@totals[from] / 100).round(2)}."
