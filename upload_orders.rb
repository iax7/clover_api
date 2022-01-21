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
CATALOG_FILE = ENV.fetch("ORDER_CATALOG_FILE", "catalogs/orders_catalog.yml")

clover = Api::Clover.new(CLOVER_ENV.to_sym, CL_MERCHANT_ID, CL_TOKEN)
puts "Loading catalog file: \e[33m#{CATALOG_FILE}\e[0m..."
catalog = YAML.load_file(CATALOG_FILE)

def result(res)
  # JSON.parse(res.body, symbolize_names: true)
  res.body
end

Helpers::Helper.headline("Orders")
orders_idx = {}
catalog["orders"].each do |order|
  puts "Creating Order \e[33m#{order["order"]}\e[0m"

  # Verify if use atomic order from clover api or use order from ecommerce api
  if catalog["atomic"]
    # Iterate each order and set the items and order type options
    items = clover.set_order_items(order)
    order_type = clover.set_order_type(order)
    shipping = clover.set_order_shipping(order)

    # Iterate each item for this order
    items.each_with_index do |item, index|
      # Get the inventory item id by sku
      inventory_item_id = clover.get_method("items", { filter: "sku=#{item[:sku]}" })

      # If was found an item in the inventory then add it to items array
      items[index][:item] = { id: inventory_item_id.first[:id] } if inventory_item_id.first[:id]
    end

    # Get all order types by merchant
    order_types = clover.get_method("order_types", {})
    order_types.each do |type|
      # If was found an order type the add it to order_type object
      order_type[:id] = type[:id] if type[:label] == order_type[:order_type]
    end

    # Raise a exception if order type was not found
    unless order_type[:id]
      raise ArgumentError,
            "Order type '#{order_type[:order_type]}' does not exists. Setting up in Setup->Order Types"
    end

    # Create new atomic order
    new_order = result clover.atomic_order_create(order, items, order_type, shipping)

    # Get service charge by merchant
    service_charge = clover.get_method("default_service_charge", {})

    # Raise a exception if service charge was not found
    unless service_charge[:enabled]
      raise ArgumentError,
            "Service Charge '#{service_charge[:id]}' does not exists or is not enabled. Setting up in Setup->Additional Charges"
    end

    # Create the service charges or fees to an order
    new_service_charge = result clover.service_charge_create(new_order[:id], order["fees"], service_charge[:id])

    # Create the discounts to an order
    new_discount = result clover.discount_create(new_order[:id], order["discounts"])

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
      inventory_item_id = clover.get_method("items", { filter: "sku=#{item[:sku]}" })

      # If was found an item in the inventory then proceed to create it
      if inventory_item_id.first[:id]
        puts "Creating Line Item \e[33m#{inventory_item_id.first[:id]}\e[0m | #{item[:sku]}"
        result = clover.line_item_create(new_order[:id], inventory_item_id.first[:id])
      end
    end
  end
  orders_idx[new_order[:order]] = new_order[:id]
end
