#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "dotenv/load"
require "faraday"
require "json"
require "pry"
require_relative "api/bigcommerce"
require_relative "helpers/helper"

BC_STORE_HASH = ENV["BC_STORE_HASH"]
BC_TOKEN = ENV["BC_TOKEN"]
CATALOG_FILE = ENV.fetch("ORDER_CATALOG_FILE", "catalogs/orders_catalog.yml")

bigcommerce = Api::Bigcommerce.new(BC_STORE_HASH, BC_TOKEN)
puts "Loading catalog file: \e[33m#{CATALOG_FILE}\e[0m..."
catalog = YAML.load_file(CATALOG_FILE)

def result(res)
  JSON.parse(res.body, symbolize_names: true)
end

Helpers::Helper.headline("Orders")
catalog["orders"].each do |order|
  puts "Creating Order \e[33m#{order["order"]}\e[0m"

  billing_address = bigcommerce.set_billing_address(order)
  products = bigcommerce.set_order_product_items(order)

  # Create new order
  new_order = result bigcommerce.order_create(order, products, billing_address)
end
