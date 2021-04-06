#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'dotenv/load'
require 'faraday'
require 'json'
require 'pry'

require_relative 'api/clover'
require_relative 'helpers/helper'

MERCHANT_ID = ENV['MERCHANT_ID']
TOKEN = ENV['TOKEN']

clover = Api::Clover.new(:dev, MERCHANT_ID, TOKEN)

Helpers::Helper.headline 'Categories'
categories = clover.get_method('categories')
puts "Total: #{categories.size}"
categories.each do |category|
  puts "Deleting #{category[:id]} - #{category[:name].inspect}..."
  clover.category_delete(category[:id])
end

puts

Helpers::Helper.headline 'Item Groups'
item_groups = clover.get_method('item_groups')
puts "Total: #{item_groups.size}"
item_groups.each do |ig|
  puts "Deleting #{ig[:id]} - #{ig[:name].inspect}..."
  clover.item_group_delete(ig[:id])
end
