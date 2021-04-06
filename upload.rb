#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'dotenv/load'
require 'faraday'
require 'json'
require 'pry'

require_relative 'api/clover'
require_relative 'helpers/helper'

CLOVER_ENV = ENV.fetch('CLOVER_ENV', 'dev')
MERCHANT_ID = ENV['MERCHANT_ID']
TOKEN = ENV['TOKEN']

clover = Api::Clover.new(CLOVER_ENV.to_sym, MERCHANT_ID, TOKEN)
catalog = YAML.load_file('products.yml')

def result(res)
  JSON.parse(res.body, symbolize_names: true)
end

Helpers::Helper.headline('Categories')
categories_idx = {}
catalog['categories'].each do |category_name|
  puts "Creating Category: #{category_name}"
  new_category = result clover.category_create(category_name)
  categories_idx[new_category[:name]] = new_category[:id]
end

Helpers::Helper.headline('Products')
catalog['products'].each do |product|
  name = product['name']
  puts "Creating #{name}"
  item_group = result clover.item_group_create(name)

  attributes = []
  product['attributes'].each do |a_name|
    attributes << result(clover.attributes_create(item_group[:id], a_name))
  end

  opt = []
  product['options'].each do |a_name, options_list|
    options_list.each do |o_name|
      attr_id = attributes.find { |a| a[:name] == a_name }[:id]
      opt << result(clover.options_create(attr_id, o_name))
    end
  end

  ao_ids = clover.group_attr_opt_ids(attributes, opt)

  num_variants = product['options'].values.map(&:size).reduce(&:*)
  puts "  Number of expected variants: #{num_variants}"
  combinations = clover.attr_opt_combinations(ao_ids)

  vars = []
  max_sku_name_size = product['variants'].map { _1['sku'].size }.max
  product['variants'].each do |variant|
    puts "  > creating variant: #{variant['sku'].ljust(max_sku_name_size)} | #{variant['name']}"
    new_var = result(clover.product_create(item_group[:id], variant['name'], variant['sku'], variant['price']))
    new_var[:_options] = combinations.shift
    vars << new_var

    clover.category_items(new_var[:id], categories_idx, product['categories']) if product['categories']&.size&.positive?
    clover.stock_create(new_var[:id], variant['stock']) if variant['stock']
  end

  clover.option_item(vars)
  puts
end
