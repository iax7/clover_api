require "yaml" 
require 'dotenv/load'
require 'faraday'
require 'json'
require 'pry'

MERCHANT_ID = ENV['MERCHANT_ID']
TOKEN = ENV['TOKEN']

BASE_URLS = {
  dev: 'apisandbox.dev.clover.com',
  prod: 'api.clover.com'
}.freeze

BASE_URL = "https://#{BASE_URLS[:dev]}/v3/merchants/#{MERCHANT_ID}"

headers = {
  'Content-Type' => 'application/json',
  'Accept' => 'application/json',
  'Authorization' => "Bearer #{TOKEN}"
}.freeze
@client = Faraday.new(url: BASE_URL, headers: headers)

products = YAML.load_file('products.yml')
# Changes ----------------------------------------------------------------------
def item_group(name)
    data = {
      name: name
    }
   @client.post('item_groups', data.to_json)
  end

def attributes(item_group_id, name)
    data = {
      name: name,
      itemGroup: {
        id: item_group_id
      }
    }
    @client.post('attributes', data.to_json)
  end

  def options(attribute_id, name)
    data = {
      name: name
    }
    @client.post("attributes/#{attribute_id}/options", data.to_json)
  end
  
  def product(item_group_id,name,sku,price)
    id = Time.now.to_i
    ig = {
      id: item_group_id
    }
    # name, price REQUIRED
    prd = {
      name: name,
      sku: sku,
      price: price,
    }
    prd[:itemGroup] = ig if item_group_id
    @client.post('items', prd.to_json, { 'expand' => 'categories,modifierGroups,itemStock,options' })
  end
  def result(res)
    JSON.parse(res.body, symbolize_names: true)

  end

products["products"].each do |i|
    it = result item_group(i["name"])

    attr = []
    i["attributes"].each do |a|
        attr << result(attributes(it[:id],a))
    end

    opt = []
    i["options"].each do |k,v|
        v.each do |o|
            binding.pry
            attr_id = attr.find {|a|a[:name]==k}[:id]
            opt << result(options(attr_id,o))
        end
    end
end
