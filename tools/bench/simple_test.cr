# Simple test to verify our benchmark infrastructure works

require "./benchmark"

puts "Testing basic benchmark infrastructure..."

runner = Hecate::Benchmark::Runner.new(warmup_iterations: 2, benchmark_iterations: 5)

# Simple CPU benchmark
result = runner.benchmark("Array creation") do
  1000.times { Array.new(100) { |i| i } }
end

puts "Test completed successfully!"
puts "Result: #{result.mean} seconds (#{result.iterations} iterations)"

# Test fixture generation
json = Hecate::Benchmark::Fixtures.generate_json(:small)
puts "Generated JSON (#{json.bytesize} bytes):"
puts json[0..100] + "..."
