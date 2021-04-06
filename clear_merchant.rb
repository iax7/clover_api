#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'dotenv/load'
require 'faraday'
require 'json'
require 'pry'

require_relative 'api/clover'

MERCHANT_ID = ENV['MERCHANT_ID']
TOKEN = ENV['TOKEN']

clover = Api::Clover.new(:dev, MERCHANT_ID, TOKEN)

# Prints visual separator in shell for easier reading for humans
# @example output
#   [Title Text] -----------------------
# @param msg [String]
# @return [void]
def headline(msg)
  line_length = 70 - (msg.size + 3)
  puts "\n[\033[1;34m#{msg}\033[0m] \033[1;31m#{"—" * line_length}\033[0m"
end

headline 'Categories'
categories = clover.get_method('categories')
puts "Total: #{categories.size}"
categories.each do |category|
  puts "Deleting #{category[:id]} - #{category[:name].inspect}..."
  clover.category_delete(category[:id])
end

puts

headline 'Item Groups'
item_groups = clover.get_method('item_groups')
puts "Total: #{item_groups.size}"
item_groups.each do |ig|
  puts "Deleting #{ig[:id]} - #{ig[:name].inspect}..."
  clover.item_group_delete(ig[:id])
end
