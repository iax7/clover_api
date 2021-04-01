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

categories = clover.get_method('categories')
puts "Total: #{categories.size}"
categories.each do |category|
  puts "Deleting #{category[:id]} - #{category[:name].inspect}..."
  clover.category_delete(category[:id])
end
