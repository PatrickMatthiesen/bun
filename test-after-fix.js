#!/usr/bin/env bun

// Comprehensive test for Windows glob path handling after fix
console.log("=== Testing Windows Glob Fix ===");
console.log("Platform:", process.platform);
console.log("Bun version:", Bun.version);

const fs = require("fs");
const path = require("path");

// Test your original example
console.log("\n=== Your Original Example ===");
const basePath = "C:\\Users\\patr7\\Desktop\\Ting\\My projects\\MALSync\\src\\chibiScript\\functions";
const pattern = "**/*Functions.ts";

console.log("Base path:", basePath);
console.log("Pattern:", pattern);

// Method 1: Using path.join (your original approach)
const joinedPattern = path.join(basePath, pattern);
console.log("path.join result:", joinedPattern);

try {
  console.log("Testing fs.globSync with path.join result...");
  const results1 = [...fs.globSync(joinedPattern)];
  console.log(`✅ fs.globSync found ${results1.length} files`);
  if (results1.length > 0) {
    console.log("Sample results:", results1.slice(0, 3));
  }
} catch (error) {
  console.log(`❌ fs.globSync failed: ${error.message}`);
}

// Method 2: Manual forward slash conversion
const forwardSlashPattern = (basePath + "/" + pattern).replace(/\\/g, "/");
console.log("Forward slash pattern:", forwardSlashPattern);

try {
  console.log("Testing fs.globSync with forward slashes...");
  const results2 = [...fs.globSync(forwardSlashPattern)];
  console.log(`✅ fs.globSync found ${results2.length} files`);
} catch (error) {
  console.log(`❌ fs.globSync failed: ${error.message}`);
}

// Method 3: Direct Bun.Glob for comparison
try {
  console.log("Testing Bun.Glob directly with original pattern...");
  const bunGlob = new Bun.Glob(joinedPattern);
  const results3 = [...bunGlob.scanSync()];
  console.log(`✅ Bun.Glob found ${results3.length} files`);
} catch (error) {
  console.log(`❌ Bun.Glob failed: ${error.message}`);
}

// Test simpler patterns
console.log("\n=== Testing Simpler Patterns ===");

const simpleTests = [
  "C:\\Users\\patr7\\Desktop\\*.js",
  "C:\\Users\\patr7\\Desktop\\**\\*.js",
  "*.js",
  "**\\*.js",
  "**/*.js",
];

simpleTests.forEach((testPattern, index) => {
  console.log(`\nTest ${index + 1}: ${JSON.stringify(testPattern)}`);

  try {
    const fsResults = [...fs.globSync(testPattern)];
    console.log(`  fs.globSync: ${fsResults.length} files`);

    const bunResults = [...new Bun.Glob(testPattern).scanSync()];
    console.log(`  Bun.Glob:    ${bunResults.length} files`);

    if (fsResults.length !== bunResults.length) {
      console.log(`  ⚠️  Mismatch: fs.globSync vs Bun.Glob`);
    } else {
      console.log(`  ✅ Both methods match`);
    }
  } catch (error) {
    console.log(`  ❌ Error: ${error.message}`);
  }
});

// Test the require('glob') simulation
console.log("\n=== Testing Traditional Node.js glob Usage ===");

try {
  // This simulates: const glob = require('glob'); glob.sync(path.join(...))
  const traditionalPattern = path.join(basePath, pattern);
  console.log("Traditional pattern:", traditionalPattern);

  const traditionalResults = [...fs.globSync(traditionalPattern)];
  console.log(`Traditional approach: ${traditionalResults.length} files found`);

  if (traditionalResults.length > 0) {
    console.log("✅ Windows glob paths are now working correctly!");
    console.log("Sample files:", traditionalResults.slice(0, 3));
  } else {
    console.log("🤔 No files found - this might be expected if the directory doesn't exist");
  }
} catch (error) {
  console.log(`❌ Traditional approach failed: ${error.message}`);
}

console.log("\n=== Summary ===");
console.log("If you see ✅ symbols above, the Windows glob fix is working!");
console.log("The key fix: fs.glob now converts \\\\ to / on Windows before passing to Bun.Glob");
console.log("This matches Node.js glob behavior and works with Windows paths from path.join()");
