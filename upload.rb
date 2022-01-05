#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "dotenv/load"
require "faraday"
require "faraday_middleware"
require "json"
require "pry"

require_relative "api/clover"
require_relative "helpers/helper"

CLOVER_ENV = ENV.fetch("CLOVER_ENV", "dev")
CL_MERCHANT_ID = ENV["CL_MERCHANT_ID"]
CL_TOKEN = ENV["CL_TOKEN"]
CATALOG_FILE = ENV.fetch("UPLOAD_CATALOG_FILE", "catalogs/upload_catalog.yml")

clover = Api::Clover.new(CLOVER_ENV.to_sym, CL_MERCHANT_ID, CL_TOKEN)
puts "Loading catalog file: \e[33m#{CATALOG_FILE}\e[0m..."
catalog = YAML.load_file(CATALOG_FILE)

categories_idx = {}

def result(res)
  # JSON.parse(res.body, symbolize_names: true)
  res.body
end

create_product = proc do |product|
  name = product["name"]
  puts "Creating \e[33m#{name}\e[0m (No variants)"

  new_prd = clover.product_create(nil, product["name"], product["sku"], product["price"])
  clover.category_items(new_prd[:id], categories_idx, product["categories"]) if product["categories"]&.size&.positive?
  clover.stock_create(new_prd[:id], product["stock"]) if product["stock"]
end

product_with_variants = proc do |product|
  name = product["name"]
  puts "Creating \e[33m#{name}\e[0m"
  item_group = result(clover.item_group_create(name))

  attributes = []
  product["attributes"].each do |a_name|
    attributes << result(clover.attributes_create(item_group[:id], a_name))
  end

  opt = []
  product["options"].each do |a_name, options_list|
    options_list.each do |o_name|
      attr_id = attributes.find { |a| a[:name] == a_name }[:id]
      opt << result(clover.options_create(attr_id, o_name))
    end
  end

  ao_ids = clover.group_attr_opt_ids(attributes, opt)

  num_variants = product["options"].values.map(&:size).reduce(&:*)
  puts "  Number of expected variants: #{num_variants}"
  combinations = clover.attr_opt_combinations(ao_ids)

  vars = []
  max_sku_name_size = product["variants"].map { _1["sku"]&.size }.compact.max
  product["variants"].each do |variant|
    puts "  > creating variant: #{variant["sku"]&.ljust(max_sku_name_size)} | #{variant["name"]}"
    new_var = result(clover.product_create(item_group[:id], variant["name"], variant["sku"], variant["price"]))
    new_var[:_options] = combinations.shift
    vars << new_var

    clover.category_items(new_var[:id], categories_idx, product["categories"]) if product["categories"]&.size&.positive?
    clover.stock_create(new_var[:id], variant["stock"]) if variant["stock"]
  end

  clover.option_item(vars)
end

Helpers::Helper.headline("Categories")
catalog["categories"].each do |category_name|
  puts "Creating \e[33m#{category_name}\e[0m"
  new_category = result(clover.category_create(category_name))
  categories_idx[new_category[:name]] = new_category[:id]
end

Helpers::Helper.headline("Products")
catalog["products"].each do |product|
  product["variants"].nil? ? create_product.call(product) : product_with_variants.call(product)
  puts
end
