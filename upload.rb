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
catalog = YAML.load_file('products.yml')

def result(res)
  JSON.parse(res.body, symbolize_names: true)
end

categories_idx = {}
catalog['categories'].each do |cat_name|
  puts "Creating Category: #{cat_name}"
  cat = result clover.category_create(cat_name)
  categories_idx[cat[:name]] = cat[:id]
end

catalog['products'].each do |i|
  name = i['name']
  puts "Creating #{name}"
  it = result clover.item_group_create(name)
  attr = []
  i['attributes'].each do |a|
    attr << result(clover.attributes_create(it[:id], a))
  end

  opt = []
  i['options'].each do |k,v|
    v.each do |o|
      attr_id = attr.find { |a| a[:name] == k }[:id]
      opt << result(clover.options_create(attr_id, o))
    end
  end

  ao_ids = clover.group_attr_opt_ids(attr, opt)

  num_variants = i['options'].values.map(&:size).reduce(&:*)
  combinations = clover.attr_opt_combinations(ao_ids)

  vars = []
  i['variants'].each do |var|
    new_var = result(clover.product_create(it[:id], var['name'], var['sku'], var['price']))
    new_var[:_options] = combinations.shift
    vars << new_var

    clover.category_items(new_var[:id], categories_idx, i['categories']) if i['categories']&.size&.positive?
    clover.stock_create(new_var[:id], var['stock']) if var['stock']
  end

  clover.option_item(vars)
end
