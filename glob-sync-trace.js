#!/usr/bin/env bun

// Focused test to trace glob.sync() call as used in your example
const glob = require("glob");
const path = require("path");

console.log("=== Tracing glob.sync() call ===");

// Your original code:
const testPath = path.join(
  "C:\\Users\\patr7\\Desktop\\Ting\\My projects\\MALSync\\src\\chibiScript\\functions",
  "**/*Functions.ts",
);

console.log("Original path.join result:", testPath);
console.log("Raw string:", JSON.stringify(testPath));

// What happens when we call glob.sync()
console.log("\n=== Testing glob.sync() ===");

try {
  console.log("Calling glob.sync with:", testPath);
  const results = glob.sync(testPath);
  console.log("glob.sync returned:", results.length, "results");
  console.log("Results:", results);
} catch (error) {
  console.error("glob.sync error:", error.message);
  console.error("Error details:", error);
}

// Let's also test with different path formats
console.log("\n=== Testing different path formats ===");

const formats = [
  // Original Windows format
  testPath,
  // Manually converted to forward slashes
  testPath.replace(/\\/g, "/"),
  // Using posix join
  path.posix.join(
    "C:\\Users\\patr7\\Desktop\\Ting\\My projects\\MALSync\\src\\chibiScript\\functions",
    "**/*Functions.ts",
  ),
  // Double backslash format
  "C:\\\\Users\\\\patr7\\\\Desktop\\\\Ting\\\\My projects\\\\MALSync\\\\src\\\\chibiScript\\\\functions\\\\**\\\\*Functions.ts",
];

formats.forEach((format, index) => {
  console.log(`\nFormat ${index + 1}:`, JSON.stringify(format));
  try {
    const results = glob.sync(format);
    console.log(`  Results: ${results.length} files`);
    if (results.length > 0) {
      console.log(`  Sample:`, results.slice(0, 2));
    }
  } catch (error) {
    console.log(`  Error:`, error.message);
  }
});

// Test with a simpler pattern to see if glob works at all
console.log("\n=== Testing with simpler patterns ===");

const simpleTests = ["C:\\Users\\patr7\\Desktop\\*.js", "C:/Users/patr7/Desktop/*.js", "./**.js", "./**/*.js"];

simpleTests.forEach((pattern, index) => {
  console.log(`\nSimple test ${index + 1}:`, JSON.stringify(pattern));
  try {
    const results = glob.sync(pattern);
    console.log(`  Results: ${results.length} files`);
  } catch (error) {
    console.log(`  Error:`, error.message);
  }
});

// Test Bun.Glob directly for comparison
console.log("\n=== Comparing with Bun.Glob ===");

formats.forEach((format, index) => {
  console.log(`\nBun.Glob format ${index + 1}:`, JSON.stringify(format));
  try {
    const bunGlob = new Bun.Glob(format);
    const results = [...bunGlob.scanSync()];
    console.log(`  Bun.Glob results: ${results.length} files`);
    if (results.length > 0) {
      console.log(`  Sample:`, results.slice(0, 2));
    }
  } catch (error) {
    console.log(`  Bun.Glob error:`, error.message);
  }
});

console.log("\n=== Analysis ===");
console.log("This shows how the require('glob') module handles different path formats");
console.log("vs how Bun.Glob handles them internally.");
