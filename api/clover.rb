# frozen_string_literal: true

module Api
  # Handles all Clover API
  class Clover
    BASE_URLS = {
      dev: "sandbox.dev.clover.com",
      prod: "api.clover.com"
    }.freeze
    DEFAULT_QUERY_PARAMS = {
      limit: 500, # limit cannot be greater than 1000
      offset: 0
    }.freeze

    # Constant of Clover Ecommerce API
    ECOMM_URLS = {
      dev: "scl-sandbox.dev.clover.com",
      prod: "scl.clover.com"
    }.freeze

    # @param env [Symbol]
    # @param merchant_id [String]
    # @param token [String]
    # @return [self]
    def initialize(env, merchant_id, token)
      raise ArgumentError, "CLOVER_ENV should be one of #{BASE_URLS.keys.inspect}" unless BASE_URLS.keys.include?(env)

      url = "https://#{BASE_URLS[env]}/v3/merchants/#{merchant_id}/"
      @env = env
      @merchant_id = merchant_id
      @connection = Faraday.new(url: url) do |faraday|
        faraday.request :authorization, "Bearer", token
        faraday.request :json
        faraday.response :json, parser_options: { symbolize_names: true }
        faraday.adapter Faraday.default_adapter
      end
    end

    def category_create(name)
      data = {
        name: name
      }
      connection.post("categories", data.to_json)
    end

    def category_delete(id)
      connection.delete("categories/#{id}")
    end

    def category_items(product_id, categories_idx, categories)
      elements = []
      categories.each_with_object(elements) do |name, res|
        category_id = categories_idx[name]
        res << { category: { id: category_id }, item: { id: product_id } }
      end

      itm_opt = {
        elements: elements
      }
      connection.post("category_items", itm_opt.to_json)
    end

    def item_group_create(name)
      data = {
        name: name
      }
      connection.post("item_groups", data.to_json)
    end

    def item_group_delete(id)
      connection.delete("item_groups/#{id}")
    end

    def item_delete(id)
      connection.delete("items/#{id}")
    end

    def attributes_create(item_group_id, name)
      data = {
        name: name,
        itemGroup: {
          id: item_group_id
        }
      }
      connection.post("attributes", data.to_json)
    end

    def options_create(attribute_id, name)
      data = {
        name: name
      }
      connection.post("attributes/#{attribute_id}/options", data.to_json)
    end

    def product_create(item_group_id, name, sku, price)
      ig = {
        id: item_group_id
      }
      # name, price REQUIRED
      prd = {
        name: name,
        sku: sku,
        price: price
      }
      prd[:itemGroup] = ig if item_group_id
      connection.post("items", prd.to_json, { "expand" => "categories,modifierGroups,itemStock,options" })
    end

    # @order id [Hash]
    # @items [Array]
    # @shipping [Hash]
    # @return [Hash]
    def order_create(order, items, shipping)
      data = {
        items: items,
        shipping: shipping,
        currency: order["currency"],
        email: order["email"]
      }
      # Change url_prefix from the BASE_URLS to ECOMM_URLS of Clover API
      connection.url_prefix = base_url(for_orders: true)
      connection.post("orders", data.to_json)
    end

    # @order [Hash]
    # @order_type [String]
    # @items [Array]
    # @shipping [Hash]
    # @return [Hash]
    def atomic_order_create(order, items, order_type, shipping)
      data = {
        orderCart: {
          lineItems: items
        },
        orderType: order_type,
        currency: order["currency"],
        title: order["title"],
        note: order["note"],
        shipping: shipping
      }
      connection.post("atomic_order/orders", data.to_json)
    end

    # @order_id [String]
    # @line_item_id [String]
    # @return [Hash]
    def line_item_create(order_id, line_item_id)
      data = {
        item: { id: line_item_id }
      }
      connection.post("orders/#{order_id}/line_items", data.to_json)
    end

    # @order_id [String]
    # @line_item_id [String]
    # @options [Hash]
    # @return [Hash]
    def line_item_update(order_id, line_item_id, options)
      data = {
        price: options["price"]
      }
      connection.post("orders/#{order_id}/line_items/#{line_item_id}", data.to_json)
    end

    # @order_id [String]
    # @line_item_id [String]
    # @return [Hash]
    def order_delete(order_id)
      connection.delete("orders/#{order_id}")
    end

    # @order_id [String]
    # @line_item_id [String]
    # @return [Hash]
    def line_items_delete(order_id, line_item_id: nil)
      # Change url_prefix from the BASE_URLS to ECOMM_URLS of Clover API
      connection.url_prefix = base_url(for_orders: false)
      connection.delete("orders/#{order_id}/line_items")
    end

    # @param for_orders [Boolean]
    # @return [String]
    def base_url(for_orders: false)
      # If for_orders is true the use ECOMM_URLS in order.
      if for_orders
        "https://#{ECOMM_URLS[@env]}/v1"
      else
        "https://#{BASE_URLS[@env]}/v3/merchants/#{@merchant_id}/"
      end
    end

    # @order [Hash]
    # @return [Array]
    def set_order_items(order)
      item_array = []
      order["items"].each do |item|
        items = {}
        items[:price] = item["price"]
        items[:currency] = item["currency"]
        items[:description] = item["description"]
        items[:quantity] = item["quantity"]
        items[:type] = item["type"]
        items[:sku] = item["sku"]
        item_array << items
        item
      end
      item_array
    end

    # @order [Hash]
    # @return [Hash]
    def set_order_shipping(order)
      {
        city: order["shipping"]["city"],
        line1: order["shipping"]["line1"],
        line2: order["shipping"]["line2"],
        postal_code: order["shipping"]["postal_code"],
        state: order["shipping"]["state"],
        country: order["shipping"]["country_iso"],
        name: order["shipping"]["first_name"],
        phone: order["shipping"]["phone"]
      }
    end

    # @order [Hash]
    # @return [Hash]
    def set_order_type(order)
      {
        order_type: order["order_type"]
      }
    end

    # @order_id [String]
    # @order [Hash]
    # @service_charge_id [String]
    # @return [Hash]
    def service_charge_create(order_id, order, service_charge_id)
      data = {
        id: service_charge_id,
        name: order["name"],
        percentageDecimal: order["percentageDecimal"]
      }
      connection.post("orders/#{order_id}/service_charge", data.to_json)
    end

    # @order_id [String]
    # @order [Hash]
    # @return [Hash]
    def discount_create(order_id, order)
      data = {
        name: order["name"],
        percentage: order["percentage"]
      }
      connection.post("orders/#{order_id}/discounts", data.to_json)
    end

    # Attributes =    Color     Size
    # Options    =  Red White  32   64
    def option_item(items)
      elements = []
      create_option = ->(prd, opt) { { option: { id: opt }, item: { id: prd } } }
      items.each_with_object(elements) do |var, res|
        item = create_option.curry[var[:id]]
        var[:_options].each do |o|
          res << item.call(o)
        end
      end

      itm_opt = {
        elements: elements
      }
      connection.post("option_items", itm_opt.to_json)
    end

    def group_attr_opt_ids(attributes, options)
      attr_ids = attributes.each_with_object({}) { |a, res| res[a[:id]] = [] }
      options.each { |o| attr_ids[o.dig(:attribute, :id)] << o[:id] }
      attr_ids
    end

    def attr_opt_combinations(x)
      combinations = []
      keys = x.keys.reverse

      return x.values.first.map { [_1] } if keys.size == 1

      # positive
      pair = keys[0..1]
      b, a = pair # reversed
      keys -= pair
      combinations.concat comb(x[a], x[b])

      while keys.size.positive?
        next_val = keys.shift
        combinations = comb(x[next_val], combinations)
      end

      combinations
    end

    def comb(a, b)
      a.each_with_object([]) do |s1, res|
        b.each { |s2| res << [s1, *s2] }
      end
    end

    def stock_create(product_id, stock_count)
      itm_opt = {
        quantity: stock_count
      }
      connection.post("item_stocks/#{product_id}", itm_opt.to_json)
    end

    def get_method(endpoint, additional_params = {})
      # Change url_prefix from the BASE_URLS to ECOMM_URLS of Clover API
      connection.url_prefix = base_url(for_orders: false)
      # limit cannot be greater than 1000
      params = DEFAULT_QUERY_PARAMS.merge(additional_params)
      result = []
      (1...).each do |i|
        puts "Fetching (#{endpoint}) #{i}"
        res = connection.get(endpoint, params)
        hash = res.body
        # Verify if hash exists the key :elements in order to concat to result array
        if hash.key?(:elements)
          elements = hash[:elements]
          result.concat(elements)
          should_fetch_next = elements.size == params[:limit]
          return result unless should_fetch_next

          params[:offset] = params[:limit] + params[:offset]
        else
          # Verify if hash exists the key :elements in order to concat to result array
          return hash
        end
      end
    end

    private

    attr_reader :env, :merchant_id, :connection
  end
end
