# frozen_string_literal: true

require "faraday"
require "faraday/gzip"
require "faraday/retry"
require "json"

module Api
  # Handles all Bigcommerce API
  class Bigcommerce
    BASE_URL = "https://api.bigcommerce.com"
    DEFAULT_QUERY_PARAMS = {
      limit: 250,
      page: 1
    }.freeze

    # @param store_hash [String]
    # @param token [String]
    # @return [self]
    def initialize(store_hash, token)
      store_url = URI.join(BASE_URL, "stores/#{store_hash}/")
      @store_hash = store_hash
      @connection = Faraday.new(url: store_url, ssl: {}) do |faraday|
        faraday.headers = headers(token)
        faraday.request :json
        faraday.response :json, parser_options: { symbolize_names: true }
        faraday.request :gzip
        faraday.adapter :net_http
      end
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
      products = []
      order["items"].each do |item|
        items = {}
        items[:name] = item["description"]
        items[:quantity] = item["quantity"]
        items[:price_inc_tax] = (item["price"] / 100)
        items[:price_ex_tax] = (item["price"] / 100)
        items[:sku] = item["sku"]
        products << items
        item
      end
      products
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
      connection.post("v2/orders", data.to_json)
    end

    def product_delete(id)
      connection.delete("v3/catalog/products/#{id}")
    end

    # @param endpoint [String]
    # @param additional_params [Hash]
    # @return [Array]
    def get_method(endpoint, additional_params = {})
      query_params = DEFAULT_QUERY_PARAMS.merge(additional_params)

      total_pages = nil
      result = nil
      (1...).each do |page|
        response = connection.get(endpoint, query_params)

        result = result.nil? ? response.body[:data] : result.concat(response.body[:data])
        total_pages ||= response.body&.dig(:meta, :pagination, :total_pages)

        more_pages_to_fetch = page < total_pages
        return result unless more_pages_to_fetch

        query_params[:page] = page.next
      end
    end

    private

    attr_reader :connection, :store_hash

    def headers(token)
      {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "X-Auth-Token" => token
      }.freeze
    end
  end
end
