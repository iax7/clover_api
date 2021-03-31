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

BASE_URL = "https://#{BASE_URLS[:prod]}/v3/merchants/#{MERCHANT_ID}"

headers = {
  'Content-Type' => 'application/json',
  'Accept' => 'application/json',
  'Authorization' => "Bearer #{TOKEN}"
}.freeze
@client = Faraday.new(url: BASE_URL, headers: headers)

catalog = YAML.load_file('products.yml')
# Changes ----------------------------------------------------------------------
def category(name)
  data = {
    name: name
  }
  @client.post('categories', data.to_json)
end

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

# Attributes =    Color     Size
# Options    =  Red White  32   64
def option_item(items)
  elements = []
  create_option = ->(prd, opt) { { "option": { "id": opt }, "item": { "id": prd } } }
  items.each_with_object(elements) do |var,res|
    item = create_option.curry[var[:id]]
    var[:_options].each do |o|
      res << item.call(o)
    end
  end

  itm_opt = {
    "elements": elements
  }
  @client.post('option_items', itm_opt.to_json)
end

def result(res)
  JSON.parse(res.body, symbolize_names: true)
end

def group_attr_opt_ids(attributes, options)
  attr_ids = attributes.each_with_object({}) { |a, res| res[a[:id]] = [] }
  options.each { |o| attr_ids[o.dig(:attribute, :id)] << o[:id] }
  attr_ids
end

def attr_opt_combinations(x)
  combinations = []
  keys = x.keys.reverse

  if keys.size == 1
    return x.values.first.map { [_1] }
  end

  # positive
  pair = keys[0..1]
  b, a = pair # reversed
  keys = keys - pair
  combinations.concat comb(x[a], x[b])

  while keys.size.positive?
    next_val = keys.shift
    combinations = comb(x[next_val], combinations)
  end

  combinations
end

def comb(a,b)
  a.each_with_object([]) do |s1, res|
    b.each {|s2| res << [s1, *s2] }
  end
end

#Categories
def category_items(product_id,categories_idx,categories)
  elements = []
  categories.each_with_object(elements) do |name, res|
    category_id = categories_idx[name]
    res<<{ "category": { "id": category_id }, "item": { "id": product_id } }
  end

  itm_opt = {
    "elements": elements
  }
  @client.post('category_items', itm_opt.to_json)
end

categories_idx = {}
catalog["categories"].each do |cat_name|
  puts "Creating Category: #{cat_name}"
  cat = result category(cat_name)
  categories_idx[cat[:name]]=cat[:id]
end

#Stock
def stock(product_id,stock_count)

    itm_opt = {
      "quantity": stock_count
    }
    @client.post("item_stocks/#{product_id}", itm_opt.to_json)
end

#Products
catalog["products"].each do |i|
  name = i["name"]
  puts "Creating #{name}"
  it = result item_group(name)
  attr = []
  i["attributes"].each do |a|
      attr << result(attributes(it[:id],a))
  end

  opt = []
  i["options"].each do |k,v|
      v.each do |o|
          attr_id = attr.find {|a|a[:name]==k}[:id]
          opt << result(options(attr_id,o))
      end
  end

  ao_ids = group_attr_opt_ids(attr, opt)
  # x = {:color=>["red", "white"], :size=>[32, 64]}

  num_variants = i["options"].values.map(&:size).reduce(&:*)
  combinations = attr_opt_combinations(ao_ids)

  vars = []
  i["variants"].each do |var|
    new_var = result(product(it[:id],var["name"],var["sku"],var["price"]))
    new_var[:_options] = combinations.shift
    vars << new_var

    category_items(new_var[:id],categories_idx,i["categories"])
    stock(new_var[:id],var["stock"])
  end

  option_item(vars)

end
