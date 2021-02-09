#!/usr/bin/env ruby
# frozen_string_literal: true

# @see https://docs.clover.com/reference#inventorygetitems-1

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

def get_data(response)
  # TODO: investigate pagination
  hash = JSON.parse response.body, symbolize_names: true
  puts response.env.url.to_s
  hash[:elements]
end

headers = {
  'Content-Type' => 'application/json',
  'Accept' => 'application/json',
  'Authorization' => "Bearer #{TOKEN}"
}.freeze

client = Faraday.new(url: BASE_URL, headers: headers)
rc = get_data client.get('categories')
rp = get_data client.get('items', { 'expand' => 'categories,modifierGroups,itemStock,options' })
rg = get_data client.get('item_groups', { 'expand' => 'items,attributes' })
binding.pry

puts 'done.'

def product
  # name, price REQUIRED
  default = {
    hidden: false,
    priceType: 'FIXED',
    defaultTaxRates: true,
    isRevenue: true
  }
  id = Time.now.to_i
  default.merge(
    {
      name: "Product #{id}",
      sku: "sku #{id}",
      code: 'UPC',
      price: 19.90,
      categories: [
        { id: 'Z0QSSR8Q8EJ5C' }
      ],
      item_group: [
        id: '@#$@#$WERFEDASFSDF'
      ]
    }
  )
end
client.post('items', product.to_json, { 'expand' => 'categories,modifierGroups,itemStock,options' })

def category
  # name REQUIRED
  {
    name: "Category #{Time.now.to_i}"
  }
end
client.post('categories', category.to_json)

def item_group
  {
    name: 'MacBook Pro NEW',
    items: [
      { id: 'HC28W9N9Y1SFG' },
      { id: 'G6PBW1VVF7CQ4' },
      { id: '65QPRWCXSM2XE' },
      { id: '59HXFZCV9HA02' }
    ]
  }
end
client.post('item_groups', item_group.to_json)
