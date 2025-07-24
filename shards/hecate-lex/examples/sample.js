// A simple JavaScript example to demonstrate the lexer
function fibonacci(n) {
  if (n <= 1) {
    return n;
  }
  
  // Calculate fibonacci recursively
  return fibonacci(n - 1) + fibonacci(n - 2);
}

// Test the function
const result = fibonacci(10);
console.log("Fibonacci of 10 is", result);

// Arrow function example
const add = (a, b) => a + b;

// Object literal
const person = {
  name: "Alice",
  age: 30,
  greet: function() {
    console.log("Hello, I'm " + this.name);
  }
};

// Array and loop
let numbers = [1, 2, 3, 4, 5];
for (let i = 0; i < numbers.length; i++) {
  if (numbers[i] % 2 === 0) {
    console.log(numbers[i] + " is even");
  } else {
    console.log(numbers[i] + " is odd");
  }
}

/* Multi-line comment
   demonstrating block comments
   in JavaScript */

// Comparison operators
let x = 10;
let y = "10";
console.log(x == y);   // true (loose equality)
console.log(x === y);  // false (strict equality)
console.log(x != y);   // false
console.log(x > 5 && y < "20");  // true