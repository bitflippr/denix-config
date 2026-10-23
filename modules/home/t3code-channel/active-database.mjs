import { existsSync, readFileSync, readdirSync, readlinkSync } from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

// During the V2 cutover both databases exist. Inspect the running server's open
// files rather than treating the frozen pre-upgrade database as current activity.
export function resolveActivityDatabase(dbPath) {
  if (path.basename(dbPath) !== "state.sqlite") return dbPath;
  const nextPath = path.join(path.dirname(dbPath), "statev2.sqlite");
  if (!existsSync(nextPath)) return dbPath;
  const runtimePath = path.join(path.dirname(dbPath), "server-runtime.json");
  const { pid } = JSON.parse(readFileSync(runtimePath, "utf8"));
  if (!Number.isSafeInteger(pid) || pid <= 0) throw new Error("Invalid server runtime PID");
  let opened;
  if (process.platform === "linux") {
    opened = readdirSync(`/proc/${pid}/fd`).flatMap((fd) => {
      try { return [readlinkSync(`/proc/${pid}/fd/${fd}`)]; }
      catch (error) { if (error.code === "ENOENT") return []; throw error; }
    });
  } else if (process.platform === "darwin") {
    const result = spawnSync("/usr/sbin/lsof", ["-a", "-p", String(pid), "-Fn"], { encoding: "utf8" });
    if (result.status !== 0) throw new Error("Cannot inspect the running server's database");
    opened = result.stdout.split("\n").filter((line) => line.startsWith("n")).map((line) => line.slice(1));
  } else {
    throw new Error("Unsupported platform for database cutover activity check");
  }
  const matches = [...new Set(opened.filter((file) => file === dbPath || file === nextPath))];
  if (matches.length !== 1) throw new Error("Cannot unambiguously identify the active T3 database");
  return matches[0];
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const dbPath = process.argv[2];
  if (!dbPath) {
    process.stderr.write("Usage: active-database.mjs DB_PATH\n");
    process.exit(1);
  }
  try {
    process.stdout.write(`${resolveActivityDatabase(dbPath)}\n`);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exit(1);
  }
}
