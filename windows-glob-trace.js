#!/usr/bin/env bun

// Test file to trace glob pattern processing on Windows
// This will help us understand how the path gets transformed as it flows through Bun's codebase

const path = require("path");

console.log("=== Windows Glob Path Tracing ===");
console.log("Platform:", process.platform);
console.log("Path separator:", path.sep);

// Your original example pattern
const basePath = "C:\\Users\\patr7\\Desktop\\Ting\\My projects\\MALSync\\src\\chibiScript\\functions";
const pattern = "**/*Functions.ts";
const fullPattern = path.join(basePath, pattern);

console.log("\n=== Original Input ===");
console.log("Base path:", basePath);
console.log("Pattern:", pattern);
console.log("Full pattern (path.join):", fullPattern);

// Let's trace how different parts of the system handle the path
console.log("\n=== Path Processing ===");

// 1. Node.js path.join behavior
console.log("1. path.join result:", path.join(basePath, pattern));
console.log("   - Raw:", JSON.stringify(path.join(basePath, pattern)));

// 2. How Bun's path module handles it
console.log("2. path.posix.join:", path.posix.join(basePath, pattern));
console.log("   - Raw:", JSON.stringify(path.posix.join(basePath, pattern)));

console.log("3. path.win32.join:", path.win32.join(basePath, pattern));
console.log("   - Raw:", JSON.stringify(path.win32.join(basePath, pattern)));

// 3. Manual backslash to forward slash conversion (what Bun might do internally)
const convertedPattern = fullPattern.replace(/\\/g, "/");
console.log("4. Converted pattern (\\\ -> /):", convertedPattern);
console.log("   - Raw:", JSON.stringify(convertedPattern));

// 4. How Bun.Glob processes the pattern
console.log("\n=== Bun.Glob Processing ===");

try {
  // Test what Bun.Glob does with the original pattern
  const glob1 = new Bun.Glob(fullPattern);
  console.log("5. Bun.Glob with original pattern created successfully");
  console.log("   - Pattern:", fullPattern);

  // Test with manually converted pattern
  const glob2 = new Bun.Glob(convertedPattern);
  console.log("6. Bun.Glob with converted pattern created successfully");
  console.log("   - Pattern:", convertedPattern);

  // Test the actual scan
  console.log("\n=== Testing Glob Scan ===");

  // Create a smaller test directory structure first
  const testDir = "C:\\Users\\patr7\\Desktop";
  const testPattern = "**/*.js";
  const testFullPattern = path.join(testDir, testPattern);

  console.log("Test directory:", testDir);
  console.log("Test pattern:", testPattern);
  console.log("Test full pattern:", testFullPattern);

  const testGlob = new Bun.Glob(testFullPattern);
  const results = [...testGlob.scanSync()];
  console.log("Found", results.length, "files");
  if (results.length > 0 && results.length <= 5) {
    console.log("Sample results:", results);
  }
} catch (error) {
  console.error("Error creating Bun.Glob:", error.message);
}

// 5. Test the fs.glob function (if available)
const fs = require("fs");
if (fs.glob) {
  console.log("\n=== fs.glob Testing ===");
  try {
    // Test with a simpler pattern first
    const simplePattern = "C:\\Users\\patr7\\Desktop\\*.js";
    console.log("Testing fs.glob with:", simplePattern);

    const fsResults = [...fs.globSync(simplePattern)];
    console.log("fs.globSync results:", fsResults.length, "files");
    if (fsResults.length > 0 && fsResults.length <= 3) {
      console.log("Sample fs.glob results:", fsResults);
    }
  } catch (error) {
    console.error("Error with fs.glob:", error.message);
  }
}

// 6. Test with the pattern as you would use with require('glob')
console.log("\n=== Traditional Node.js glob pattern ===");
const traditionalPattern = basePath.replace(/\\/g, "/") + "/" + pattern;
console.log("Traditional pattern:", traditionalPattern);
console.log("   - Raw:", JSON.stringify(traditionalPattern));

try {
  const traditionalGlob = new Bun.Glob(traditionalPattern);
  console.log("Traditional pattern Bun.Glob created successfully");
} catch (error) {
  console.error("Error with traditional pattern:", error.message);
}

console.log("\n=== Summary ===");
console.log("This trace shows how different path formats are processed by Bun's glob system");
console.log("Key transformations to watch:");
console.log("1. Windows backslashes (\\) vs forward slashes (/)");
console.log("2. How path.join affects the pattern");
console.log("3. How Bun.Glob normalizes the input pattern");
console.log("4. Whether the final pattern matches the expected files");
