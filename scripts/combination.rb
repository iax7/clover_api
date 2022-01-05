require "pry"

def attr_opt_combinations(x)
  num_variants = x.values.map(&:size).reduce(&:*)
  puts "Variants #{num_variants} ----------------------------------------------"

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

x = { color: %w[red white], size: [32, 64] }
p attr_opt_combinations(x)

x = { color: %w[red white], size: [32, 64, 128] }
p attr_opt_combinations(x)

x = { color: %w[red white black], size: [32, 64] }
p attr_opt_combinations(x)

x = { color: %w[red white black] }
p attr_opt_combinations(x)

x = { color: %i[x y], size: %i[w z], top: %i[a b] }
p attr_opt_combinations(x)

x = { color: %i[x y], size: %i[w z], top: %i[a b c] }
p attr_opt_combinations(x)
