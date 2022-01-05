# frozen_string_literal: true

module Api
  # Handles all Bigcommerce API
  class Bigcommerce
    # Constant of Bigcommerce API
    BASE_URL = "api.bigcommerce.com"

    # @param store_hash [String]
    # @param token [String]
    # @return [self]
    def initialize(store_hash, token)
      base_url = "https://#{BASE_URL}/stores/#{store_hash}/v2/"
      @store_hash = store_hash
      @client = Faraday.new(url: base_url, headers: headers(token))
    end

    # @order [Hash]
    # @return [Hash]
    def set_billing_address(order)
      {
        city: order["shipping"]["city"],
        street_1: order["shipping"]["line1"],
        street_2: order["shipping"]["line2"],
        zip: order["shipping"]["postal_code"],
        state: order["shipping"]["state"],
        country: order["shipping"]["country"],
        country_iso2: order["shipping"]["country_iso"],
        first_name: order["shipping"]["first_name"],
        last_name: order["shipping"]["last_name"],
        phone: order["shipping"]["phone"]
      }
    end

    # @order [Hash]
    # @return [Array]
    def set_order_product_items(order)
      produtcs = []
      order["items"].each do |item|
        items = {}
        items[:name] = item["description"]
        items[:quantity] = item["quantity"]
        items[:price_inc_tax] = (item["price"] / 100)
        items[:price_ex_tax] = (item["price"] / 100)
        items[:sku] = item["sku"]
        produtcs << items
        item
      end
      produtcs
    end

    # @order id [Hash]
    # @items [Array]
    # @shipping [Hash]
    # @return [Hash]
    def order_create(order, products, billing_address)
      data = {
        products: products,
        billing_address: billing_address,
        discount_amount: (order["discounts"]["percentage"]),
        wrapping_cost_ex_tax: (order["fees"]["percentageDecimal"] / 1000),
        wrapping_cost_inc_tax: (order["fees"]["percentageDecimal"] / 1000)
      }
      @client.post("orders", data.to_json)
    end

    private

    def headers(token)
      {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "X-Auth-Token" => token
      }.freeze
    end
  end
end
