require "json"
require "faraday"
require "optparse"
require "active_support/core_ext/date/calculations"

BASE_URL = "https://api.octopus.energy/v1"
EXPORT_TARRIF = "AGILE-OUTGOING-19-05-13"
POSTCODE = ENV["POSTCODE"]
EXPORT_MPAN = ENV["OCTOPUS_EXPORT_MPAN"]
METER_SN = ENV["OCTOPUS_ELECTRICITY_METER_SN"]

unless ENV["OCTOPUS_API_KEY"] && POSTCODE && EXPORT_MPAN && METER_SN
  puts "Error: Missing environment variables. Check you've set all of `OCTOPUS_API_KEY`, `POSTCODE`, `EXPORT_MPAN` and `METER_SN`."
  exit(1)
end

@totals = Hash.new(0)
@client = Faraday.new do |f|
  f.request :authorization, :basic, ENV["OCTOPUS_API_KEY"], ""
end

arguments = {}
OptionParser.new do |options|
  options.banner = "Usage: octopus_payments.rb [options]"

  options.on("-f", "--from DATE", "Start date of the period (format: 2022-07-04) to calculate export for.") do |from|
    arguments[:from] = from
  end

  options.on("-t", "--to DATE", "End date of the period (format: 2022-07-04) to calculate export for.") do |to|
    arguments[:to] = to
  end

  options.on("-v", "--verbose", "Print all of the individual exports and their price.") do |verbose|
    arguments[:verbose] = verbose
  end
end.parse!

if !arguments[:from] || !arguments[:to]
  puts "Error: Please specify the dates with `--from` and `--to`."
  exit(1)
end

def find_export_tariff_geo
  gsp = JSON.parse(@client.get("#{BASE_URL}/industry/grid-supply-points/", { postcode: POSTCODE }).body)

  if gsp["results"].empty?
    puts "Error: Could not find a grid supply point for the postcode #{POSTCODE}."
    exit(1)
  end

  gsp = gsp["results"].first["group_id"].delete_prefix("_")

  "E-1R-#{EXPORT_TARRIF}-#{gsp}"
end

def query_export_prices(from, to)
  prices_response = @client.get(
    "#{BASE_URL}/products/#{EXPORT_TARRIF}/electricity-tariffs/#{find_export_tariff_geo}/standard-unit-rates/",
      {
        page_size: 1500,
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
      page_size: 25000,
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

from = DateTime.parse(arguments[:from]).beginning_of_day.strftime("%Y-%m-%dT%H:%M:%SZ")
to = DateTime.parse(arguments[:to]).end_of_day.strftime("%Y-%m-%dT%H:%M:%SZ")

query_generated_electricity(from, to).each do |result|
  next if result["consumption"].zero?

  export = result["consumption"]
  start = DateTime.parse(result["interval_start"]).strftime("%Y-%m-%dT%H:%M:%SZ")
  payment_per_kwh = calculate_payment_per_kwh(export, start, from, to)

  puts "Exported #{export} kW at #{start}, earning #{payment_per_kwh.round(2)}p." if arguments[:verbose]

  @totals[arguments[:from]] += payment_per_kwh
end

message = "Total for #{arguments[:from]}"
message += " to #{arguments[:to]}" if arguments[:from] != arguments[:to]
message += ": #{@totals[arguments[:from]].round(2)}p, or £#{(@totals[arguments[:from]] / 100).round(2)}."

puts message
