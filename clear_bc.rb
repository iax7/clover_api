#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "dotenv/load"
require "faraday"
require "faraday_middleware"
require "json"
require "pry"

require_relative "api/bigcommerce"
require_relative "helpers/helper"

bc_store_hash = ENV["BC_STORE_HASH"]
bc_token = ENV["BC_TOKEN"]

bc_client = Api::Bigcommerce.new(bc_store_hash, bc_token)

Helpers::Helper.headline "Products"
products = bc_client.get_method("v3/catalog/products")
puts "Total: #{products.size}"
products.each do |item|
  puts "Deleting #{item[:id]} - #{item[:name].inspect}..."
  bc_client.product_delete(item[:id])
end
