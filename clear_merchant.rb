#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "dotenv/load"
require "faraday"
require "json"
require "pry"

require_relative "api/clover"
require_relative "helpers/helper"

CLOVER_ENV = ENV.fetch("CLOVER_ENV", "dev")
CL_MERCHANT_ID = ENV["CL_MERCHANT_ID"]
CL_TOKEN = ENV["CL_TOKEN"]

clover = Api::Clover.new(CLOVER_ENV.to_sym, CL_MERCHANT_ID, CL_TOKEN)

Helpers::Helper.headline "Categories"
categories = clover.get_method("categories")
puts "Total: #{categories.size}"
categories.each do |category|
  puts "Deleting #{category[:id]} - #{category[:name].inspect}..."
  clover.category_delete(category[:id])
end

Helpers::Helper.headline "Item Groups"
item_groups = clover.get_method("item_groups")
puts "Total: #{item_groups.size}"
item_groups.each do |ig|
  puts "Deleting #{ig[:id]} - #{ig[:name].inspect}..."
  clover.item_group_delete(ig[:id])
end

Helpers::Helper.headline "Products"
items = clover.get_method("items")
puts "Total: #{items.size}"
items.each do |ig|
  puts "Deleting #{ig[:id]} - #{ig[:name].inspect}..."
  clover.item_delete(ig[:id])
end

Helpers::Helper.headline "Orders"
orders = clover.get_method("orders", {})
puts "Total: #{orders.size}"
orders.each do |order|
  puts "Deleting Order \e[33m#{order[:id]}\e[0m"
  clover.order_delete(order[:id])
end
