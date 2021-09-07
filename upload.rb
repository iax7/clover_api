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

CATALOG_FILE = ENV.fetch('CATALOG_FILE', 'upload_catalog.yml')

clover = Api::Clover.new(CLOVER_ENV.to_sym, MERCHANT_ID, TOKEN)
puts "Loading catalog file: \e[33m#{CATALOG_FILE}\e[0m..."
catalog = YAML.load_file(CATALOG_FILE)

def result(res)
  JSON.parse(res.body, symbolize_names: true)
end

Helpers::Helper.headline('Categories')
categories_idx = {}
catalog['categories'].each do |category_name|
  puts "Creating \e[33m#{category_name}\e[0m"
  new_category = result clover.category_create(category_name)
  categories_idx[new_category[:name]] = new_category[:id]
end

Helpers::Helper.headline('Products')
catalog['products'].each do |product|
  name = product['name']
  puts "Creating \e[33m#{name}\e[0m"
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
  max_sku_name_size = product['variants'].map { _1['sku']&.size }.compact.max
  product['variants'].each do |variant|
    puts "  > creating variant: #{variant['sku']&.ljust(max_sku_name_size)} | #{variant['name']}"
    new_var = result(clover.product_create(item_group[:id], variant['name'], variant['sku'], variant['price']))
    new_var[:_options] = combinations.shift
    vars << new_var

    clover.category_items(new_var[:id], categories_idx, product['categories']) if product['categories']&.size&.positive?
    clover.stock_create(new_var[:id], variant['stock']) if variant['stock']
  end

  clover.option_item(vars)
  puts
end

Helpers::Helper.headline('Orders')
orders_idx = {}
catalog['orders'].each do |order|
  puts "Creating Order \e[33m#{order['order']}\e[0m"

  # Verify if use atomic order from clover api or use order from ecommerce api
  if catalog['atomic']
    # Iterate each order and set the items and order type options
    items = clover.set_order_items(order)
    order_type = clover.set_order_type(order)
    shipping = clover.set_order_shipping(order)

    # Iterate each item for this order
    items.each_with_index do |item, index|
      # Get the inventory item id by sku
      inventory_item_id = clover.get_method('items', { filter: "sku=#{item[:sku]}" })

      # If was found an item in the inventory then add it to items array
      if inventory_item_id.first[:id]
        items[index][:item] = {id: inventory_item_id.first[:id]}
      end
    end

    # Get all order types by merchant
    order_types = clover.get_method('order_types', {})
    order_types.each do |type|
      # If was found an order type the add it to order_type object
      if type[:label] == order_type[:order_type]
        order_type[:id] = type[:id]
      end
    end

    # Raise a exception if order type was not found
    raise ArgumentError, "Order type '#{order_type[:order_type]}' does not exists. Setting up in Setup->Order Types" unless order_type[:id]

    # Create new atomic order
    new_order = result clover.atomic_order_create(order, items, order_type, shipping)

    # Get service charge by merchant
    service_charge = clover.get_method('default_service_charge', {})

    # Raise a exception if service charge was not found
    raise ArgumentError, "Service Charge '#{service_charge[:id]}' does not exists or is not enabled. Setting up in Setup->Additional Charges" unless service_charge[:enabled]

    # Create the service charges or fees to an order
    new_service_charge = result clover.service_charge_create(new_order[:id], order["fees"], service_charge[:id])
  else
    # Iterate each order and set the items and shipping options
    items = clover.set_order_items(order)
    shipping = clover.set_order_shipping(order)

    # Create new order
    new_order = result clover.order_create(order, items, shipping)

    # Delete the line items ids of previous order created
    response = result clover.line_items_delete(new_order[:id])

    # Iterate each item by order and create line item with options(inventory item id, price, taxRates, etc)
    items.each do |item|
      # Get the inventory item id by sku
      inventory_item_id = clover.get_method('items', { filter: "sku=#{item[:sku]}" })

      # If was found an item in the inventory then proceed to create it
      if inventory_item_id.first[:id]
        puts "Creating Line Item \e[33m#{inventory_item_id.first[:id]}\e[0m | #{item[:sku]}"
        result = clover.line_item_create(new_order[:id], inventory_item_id.first[:id])
      end
    end
  end
  orders_idx[new_order[:order]] = new_order[:id]
end