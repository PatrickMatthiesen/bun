// import { symlinkSync, writeFileSync, rmSync, hardlink } from "fs";
// import path from "path";

// const base = "x-broken-links"

// const nonExistentTarget = path.join(__dirname, base, 'non_existent_file.txt');


// const brokenSymlinkPath = path.join(__dirname, base, 'broken_link.txt');

// // symlinkSync(target, symlinkPath, "junction");
// writeFileSync(nonExistentTarget, `some text`);

// // Create the broken symlink
// symlinkSync(nonExistentTarget, brokenSymlinkPath);

// console.log(`Broken symlink created at: ${brokenSymlinkPath}`);

// rmSync(nonExistentTarget)

// new Request(`http://localhost:800/fileRoute`)
// Array.from(new Bun.Glob("../examples").scanSync({cwd: "src"}))
// Array.from(new Bun.Glob("/(function|slash)/*.{ts,cts,mts}").scanSync({cwd: "src"}))

import { describe, expect, test } from "bun:test";
import { Glob } from "bun";

// this breaks if we dont have unescape
describe("ported from micromatch / glob-match / globlin tests", () => {
  test("basic", () => {
    expect(new Glob("a\\*b").match("a*b")).toBe(true);
    expect(new Glob("a/*b").match("a*b")).toBe(true);
    expect(new Glob("\\*").match("*")).toBeTrue();
    expect(new Glob("a\\*b/*").match("a*b/ooo")).toBeTrue();
    expect(new Glob("\\!*!*.md").match("!foo!.md")).toBeTrue();

    let glob = new Glob("\\😎");
    expect(glob.match("😎")).toBeTrue();

    expect(new Glob("foo\\*/**").match("foo*/")).toBeTrue();

    // my tests
    expect(new Glob(".\\*.txt").match(".\\file.txt")).toBeTrue();
    expect(new Glob(".\\dir\\*.txt").match(".\\dir\\nested\\file.txt")).toBeTrue();
  });
});

// https://github.com/oven-sh/bun/issues/14630 - globs starting with / crashes bun

// https://github.com/oven-sh/bun/issues/18656 - glob matcher issue
// https://github.com/oven-sh/bun/issues/9937 - scripts from package json
// https://github.com/oven-sh/bun/issues/20633 - rm -rf issue again


// https://github.com/oven-sh/bun/issues/10830 - bun glob failing in Bun.FileSystemRouter
