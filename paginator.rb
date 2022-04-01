require "faraday"
require "pry"
require "dotenv/load"

merchant_id = ENV["CL_MERCHANT_ID"]
token = ENV["CL_TOKEN"]
url = "https://api.clover.com/v3/merchants/#{merchant_id}/"
connection = Faraday.new(url: url) do |faraday|
  faraday.request :authorization, "Bearer", token
  faraday.request :json
  faraday.response :json, parser_options: { symbolize_names: true }
  faraday.adapter Faraday.default_adapter
end

params = {
  limit: 1000,
  offset: 0
}

result = []
0.upto(1000).each do |i|
  params[:offset] = i * params[:limit]
  res = connection.get("items", params)
  result.concat res.body[:elements]
  puts res.body[:href]
  binding.pry if i == 50
  break if res.body[:elements].size < params[:limit]
end

binding.pry

puts result