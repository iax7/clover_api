#!/usr/bin/env ruby
# frozen_string_literal: true

# @see https://docs.clover.com/reference#inventorygetitems-1

require 'dotenv/load'
require 'faraday'
require 'json'
require 'pry'

require_relative 'api/clover'

CLOVER_ENV = ENV.fetch('CLOVER_ENV', 'dev')
CL_MERCHANT_ID = ENV['CL_MERCHANT_ID']
CL_TOKEN = ENV['CL_TOKEN']

clover = Api::Clover.new(CLOVER_ENV.to_sym, CL_MERCHANT_ID, CL_TOKEN)

rc = clover.get_method('categories')
rp = clover.get_method('items', { expand: 'categories,itemStock,options', return_null_fields: true })
rg = clover.get_method('item_groups', { expand: 'attributes' })

puts 'Digesting...'

# Main product
prd = rg.each_with_object({}) do |v, res|
  data = { id: v[:id], name: v[:name], variants: [] }
  # warning clover let you duplicate attributes name!
  opts = v.dig(:attributes, :elements)&.map { _1[:name] }&.uniq&.map { { name: _1 } }
  data[:options] = opts
  res[v[:id]] = data
end

ig_idx = rg.each_with_object({}) { |v, res| res[v[:id]] = v }

binding.pry

# processing items to add as a new product or a variant
rp.each do |var|
  prd_id = var.dig(:itemGroup, :id)
  id = var[:id]
  cat = var.dig(:categories, :elements)&.map { _1[:id] }
  name = var.dig(:options, :elements)&.first&.dig(:name)
  inv = var.dig(:itemStock, :quantity)
  new_var = {
    id: id,
    price: (var[:price].to_i / 100.0),
    sku: var[:sku],
    upc: var[:upc],
    categories: cat,
    inventory_level: inv,
    option_values: { label: name, option_display_name: nil }
  }
  if new_var[:sku].nil?
    puts "rejected #{name}, is missing SKU"
    next
  end
  if prd_id # is a variant
    parent = prd[prd_id]
    parent[:inventory_tracking] = inv.nil? ? 'none' : "variant"
    parent[:variants] << new_var
  else # is a standalone product
    new_var[:inventory_tracking] = inv.nil? ? 'none' : 'product'
    prd[id] = new_var
  end
end

puts 'done.'

# Changes ----------------------------------------------------------------------
def item_group(name)
  data = {
    name: name
  }
  client.post('item_groups', data.to_json)
end

def attributes(item_group_id, name)
  data = {
    name: name,
    itemGroup: {
      id: item_group_id
    }
  }
  client.post('attributes', data.to_json)
end

def options(name)
  data = {
    name: name
  }
  client.post("attributes/#{attribute_id}/options", data.to_json)
end

def product(item_group_id = nil)
  id = Time.now.to_i
  ig = [
    id: item_group_id
  ]
  # name, price REQUIRED
  prd = {
    name: "Product #{id}",
    sku: "sku #{id}",
    code: 'UPC',
    price: 1990
  }
  prd[:itemGroup] = ig if item_group_id
  client.post('items', prd.to_json, { 'expand' => 'categories,modifierGroups,itemStock,options' })
end

def category
  # name REQUIRED
  data = {
    name: "Category #{Time.now.to_i}"
  }
  client.post('categories', data.to_json)
end
