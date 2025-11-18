import { $ } from "bun";
import { test, expect, beforeEach } from "bun:test";
import fs from "node:fs";

const dockerVolumeDir = "parrentDir";
const dummyDirInDockerVolume = "parrentDir/dummyDir";

// Helper to ensure a clean state by removing the top-level 'parrentDir' directory
const cleanupDockerVolume = async () => {
  // Check if the directory exists before attempting to remove it
  const exists = fs.existsSync(dockerVolumeDir);
  if (exists) {
    await $`rm -rf ${dockerVolumeDir}`.quiet();
  }
};

const rmDir = async (root: string, dirs: string): Promise<void> => {
  const list = dirs.split(" ").filter(d => d.length > 0); // Filter out empty strings from split
  console.log(`removing in ${root} folders: ${dirs}`);
  for (const dir of list) {
    const path = root !== "" ? `${root}/${dir}` : dir;
    // Bun's $`rm -rf ${path}` handles both files and directories
    await $`rm -rf ${path}`.quiet();
  }
};

beforeEach(async () => {
  await cleanupDockerVolume(); // Clean before each test to ensure a consistent starting state
});

test("bunremove script equivalent (mkdir -p parrentDir/dummyDir && rm -rf parrentDir)", async () => {
  // Step 1: Equivalent of "dummyDir" script: mkdir -p parrentDir/dummyDir
  await $`mkdir ${dockerVolumeDir}`.quiet();
  expect(fs.existsSync(dockerVolumeDir)).toBe(true);

  // Step 2: rm -rf parrentDir
  await $`rm -rf ${dockerVolumeDir}`.quiet();
  expect(fs.existsSync(dockerVolumeDir)).toBe(false);
});

// fails on windows
test("bunremoverelative script equivalent (mkdir -p parrentDir/dummyDir && rm -rf ./parrentDir)", async () => {
  // Step 1: mkdir -p parrentDir/dummyDir
  await $`mkdir ./${dockerVolumeDir}`.quiet();
  expect(fs.existsSync(dockerVolumeDir)).toBe(true);

  // Step 2: rm -rf ./parrentDir
  await $`rm -rf ./${dockerVolumeDir}`.quiet();
  expect(fs.existsSync(dockerVolumeDir)).toBe(false);
});

test("bunremovenested script equivalent (mkdir -p parrentDir/dummyDir && rm -rf parrentDir/dummyDir)", async () => {
  // Step 1: mkdir -p parrentDir/dummyDir
  await $`mkdir -p ${dummyDirInDockerVolume}`.quiet();
  expect(fs.existsSync(dummyDirInDockerVolume)).toBe(true);

  // Step 2: rm -rf parrentDir/dummyDir
  await $`rm -rf ${dummyDirInDockerVolume}`.quiet();
  expect(fs.existsSync(dummyDirInDockerVolume)).toBe(false);

  expect(fs.existsSync(dockerVolumeDir)).toBe(true);

  await $`rm -rf ${dockerVolumeDir}`.quiet();
  expect(fs.existsSync(dockerVolumeDir)).toBe(false);
});

// fails on windows
test("bunremovenestedrelative script equivalent (mkdir -p parrentDir/dummyDir && rm -rf ./parrentDir/dummyDir)", async () => {
  // Step 1: mkdir -p parrentDir/dummyDir
  await $`mkdir -p ./${dummyDirInDockerVolume}`.quiet();
  expect(fs.existsSync(dummyDirInDockerVolume)).toBe(true);

  // Step 2: rm -rf ./parrentDir/dummyDir
  await $`rm -rf ./${dummyDirInDockerVolume}`.quiet();
  expect(fs.existsSync(dummyDirInDockerVolume)).toBe(false);

  expect(fs.existsSync(dockerVolumeDir)).toBe(true);

  await $`rm -rf ./${dockerVolumeDir}`.quiet();
  expect(fs.existsSync(dockerVolumeDir)).toBe(false);
});

// fails on windows
test("rmDir functionality for multiple directories and files", async () => {
  const itemsToCreateAndRemove = [
    { path: ".nx", type: "dir" },
    { path: "dist", type: "dir" },
    { path: "node_modules", type: "dir" },
    { path: "target", type: "dir" },
    { path: ".env", type: "file" },
    { path: ".husky/_", type: "dir" }, // This will create .husky and .husky/_
  ];

  // Create items
  for (const item of itemsToCreateAndRemove) {
    if (item.type === "dir") {
      await $`mkdir -p husky-test/${item.path}`.quiet();
      expect(fs.existsSync(`husky-test/${item.path}`)).toBe(true);
    } else {
      await $`touch ${item.path}`.quiet();
      expect(fs.existsSync(`${item.path}`)).toBe(true);
    }
  }
  // sleepSync(3000); // Ensure the file system has time to register the changes
  const dirsString = ".nx/ dist/ node_modules/ target/ .env .husky/_/";
  await rmDir("husky-test/", dirsString);

  // Assert items are removed
  for (const item of itemsToCreateAndRemove) {
    // console.log(`Checking existence of husky-test/${item}`);
    expect(fs.existsSync(`husky-test/${item}`)).toBe(false);
  }
});
