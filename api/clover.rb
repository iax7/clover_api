# frozen_string_literal: true

module Api
  # Handles all Clover API calls
  class Clover
    BASE_URLS = {
      dev: 'apisandbox.dev.clover.com',
      prod: 'api.clover.com'
    }.freeze

    # @param env [Symbol]
    # @param merchant_id [String]
    # @param token [String]
    # @return [self]
    def initialize(env, merchant_id, token)
      base_url = "https://#{BASE_URLS[env]}/v3/merchants/#{merchant_id}"
      @client = Faraday.new(url: base_url, headers: headers(token))
    end

    def category_create(name)
      data = {
        name: name
      }
      @client.post('categories', data.to_json)
    end

    def category_delete(id)
      @client.delete("categories/#{id}")
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
      @client.post('category_items', itm_opt.to_json)
    end

    def item_group_create(name)
      data = {
        name: name
      }
      @client.post('item_groups', data.to_json)
    end

    def item_group_delete(id)
      @client.delete("item_groups/#{id}")
    end

    def attributes_create(item_group_id, name)
      data = {
        name: name,
        itemGroup: {
          id: item_group_id
        }
      }
      @client.post('attributes', data.to_json)
    end

    def options_create(attribute_id, name)
      data = {
        name: name
      }
      @client.post("attributes/#{attribute_id}/options", data.to_json)
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
      @client.post('items', prd.to_json, { 'expand' => 'categories,modifierGroups,itemStock,options' })
    end

    # Attributes =    Color     Size
    # Options    =  Red White  32   64
    def option_item(items)
      elements = []
      create_option = ->(prd, opt) { { "option": { "id": opt }, "item": { "id": prd } } }
      items.each_with_object(elements) do |var,res|
        item = create_option.curry[var[:id]]
        var[:_options].each do |o|
          res << item.call(o)
        end
      end

      itm_opt = {
        "elements": elements
      }
      @client.post('option_items', itm_opt.to_json)
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
      keys = keys - pair
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
        "quantity": stock_count
      }
      @client.post("item_stocks/#{product_id}", itm_opt.to_json)
    end

    def get_method(endpoint, other_params = {})
      # limit cannot be greater than 1000
      params = {
                 limit: 1000,
                 offset: 0
               }.merge(other_params)
      result = []
      (1...).each do |i|
        puts "Fetching (#{endpoint}) #{i}"
        res = @client.get(endpoint, params)
        hash = JSON.parse(res.body, symbolize_names: true)
        elements = hash[:elements]
        result.concat(elements)
        should_fetch_next = elements.size == params[:limit]
        return result unless should_fetch_next

        params[:offset] = params[:limit] + params[:offset]
      end
    end

    private

    def headers(token)
      {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'Authorization' => "Bearer #{token}"
      }.freeze
    end
  end
end
