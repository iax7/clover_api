module Api
  class Clover
    BASE_URLS = {
      dev: 'apisandbox.dev.clover.com',
      prod: 'api.clover.com'
    }.freeze

    def initialize(env, merchant_id, token)
      base_url = "https://#{BASE_URLS[env]}/v3/merchants/#{merchant_id}"
      @client = Faraday.new(url: base_url, headers: headers(token))
    end

    # Changes ------------------------------------------------------------------
    def item_group(name)
      data = {
        name: name
      }
      @client.post('item_groups', data.to_json)
    end

    def attributes(item_group_id, name)
      data = {
        name: name,
        itemGroup: {
          id: item_group_id
        }
      }
      @client.post('attributes', data.to_json)
    end

    def options(attribute_id, name)
      data = {
        name: name
      }
      @client.post("attributes/#{attribute_id}/options", data.to_json)
    end

    def product(item_group_id,name,sku,price)
      id = Time.now.to_i
      ig = {
        id: item_group_id
      }
      # name, price REQUIRED
      prd = {
        name: name,
        sku: sku,
        price: price,
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

      if keys.size == 1
        return x.values.first.map { [_1] }
      end

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

    def comb(a,b)
      a.each_with_object([]) do |s1, res|
        b.each {|s2| res << [s1, *s2] }
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

    def result(res)
      JSON.parse(res.body, symbolize_names: true)
    end
  end
end
