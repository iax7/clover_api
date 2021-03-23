require 'pry'

def attr_opt_combinations(x)
  num_variants = x.values.map(&:size).reduce(&:*)
  puts "Variants #{num_variants} ----------------------------------------------"

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
    b.each {|s2| res << [s1, *s2 ] }
  end
end

x = {:color=>["red", "white"], :size=>[32, 64]}
p attr_opt_combinations(x)

x = {:color=>["red", "white"], :size=>[32, 64, 128]}
p attr_opt_combinations(x)

x = {:color=>["red", "white", "black"], :size=>[32, 64]}
p attr_opt_combinations(x)

x = {:color=>["red", "white", "black"]}
p attr_opt_combinations(x)

x = {:color=>[:x, :y], :size=>[:w, :z], :top=>[:a, :b]}
p attr_opt_combinations(x)

x = {:color=>[:x, :y], :size=>[:w, :z], :top=>[:a, :b, :c]}
p attr_opt_combinations(x)