#!/usr/bin/env bun

// Test to confirm the bug in fs.glob on Windows

console.log("=== Testing fs.glob Windows Bug ===");

const fs = require("fs");
const path = require("path");

console.log("Platform:", process.platform);

// Test patterns
const testPatterns = [
  // Forward slashes (should work)
  "C:/Users/patr7/Desktop/*.js",
  // Backslashes (currently broken due to the bug)
  "C:\\Users\\patr7\\Desktop\\*.js",
  // Mixed
  "C:\\Users\\patr7/Desktop/*.js",
];

testPatterns.forEach((pattern, index) => {
  console.log(`\nTest ${index + 1}: ${JSON.stringify(pattern)}`);

  try {
    // Test fs.globSync (the broken one)
    const fsResults = [...fs.globSync(pattern)];
    console.log(`  fs.globSync: ${fsResults.length} results`);

    // Test Bun.Glob directly (should work)
    const bunGlob = new Bun.Glob(pattern);
    const bunResults = [...bunGlob.scanSync()];
    console.log(`  Bun.Glob:    ${bunResults.length} results`);

    // Show what the validatePattern function is doing
    const processedPattern = pattern.replaceAll("/", "\\");
    console.log(`  Pattern after replaceAll("/", "\\\\"):`, JSON.stringify(processedPattern));

    const processedGlob = new Bun.Glob(processedPattern);
    const processedResults = [...processedGlob.scanSync()];
    console.log(`  Processed:   ${processedResults.length} results`);
  } catch (error) {
    console.log(`  Error: ${error.message}`);
  }
});

console.log("\n=== Demonstrating the fix ===");

const testPattern = "C:\\Users\\patr7\\Desktop\\*.js";
console.log("Original pattern:", JSON.stringify(testPattern));

// Current (broken) behavior
const broken = testPattern.replaceAll("/", "\\");
console.log("Current fs.glob logic:", JSON.stringify(broken));

// Fixed behavior (should be the opposite on Windows)
const fixed = testPattern.replaceAll("\\", "/");
console.log("Fixed logic:", JSON.stringify(fixed));

try {
  const brokenGlob = new Bun.Glob(broken);
  const brokenResults = [...brokenGlob.scanSync()];
  console.log(`Broken approach results: ${brokenResults.length}`);

  const fixedGlob = new Bun.Glob(fixed);
  const fixedResults = [...fixedGlob.scanSync()];
  console.log(`Fixed approach results: ${fixedResults.length}`);
} catch (error) {
  console.log("Error testing:", error.message);
}
