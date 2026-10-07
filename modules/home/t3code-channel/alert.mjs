#!/usr/bin/env node
// Tells T3 when the updater is stuck: posts the health file's incident to a
// T3 webhook task, which starts an agent run to fix it. One agent per stuck
// spell: no new alert until a run succeeds (`--resolved` clears the record)
// or six hours pass, so an agent whose fix exposes the next failure isn't
// joined by another. Never fails the updater. The webhook URL and its signing secret live
// in ~/.config/t3code-channel/alert.json, outside the repo and hidden from
// the agent sandbox; requests carry an HMAC-SHA256 signature, since what
// they say becomes instructions for an agent.

import { createHmac } from "node:crypto";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const [healthPath, mode] = process.argv.slice(2);
const configPath = path.join(os.homedir(), ".config/t3code-channel/alert.json");
const stateDir = process.env.T3CODE_CHANNEL_STATE_DIR ?? path.join(os.homedir(), ".local/state/t3code-channel");
const alertedPath = path.join(stateDir, "alerted.json");
const quietMs = 6 * 3600 * 1000;

if (mode === "--resolved") {
  fs.rmSync(alertedPath, { force: true });
  process.exit(0);
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return undefined;
  }
}

const config = readJson(configPath);
if (!config?.url || !config?.secret) {
  console.log("No T3 alert is configured; the incident is only in health.json.");
  process.exit(0);
}

const health = readJson(healthPath);
if (!health || !["blocked", "failed"].includes(health.status)) process.exit(0);
const incident = health.incidentKey ?? `${health.status}:${health.stage}`;
const alerted = readJson(alertedPath);
if (alerted && Date.now() - Date.parse(alerted.at) < quietMs) {
  console.log(`An agent was already alerted at ${alerted.at}; not alerting again until a run succeeds.`);
  process.exit(0);
}

let log = "";
try {
  log = execFileSync(
    "journalctl",
    ["--user", "-u", "t3code-channel-update.service", "-n", "60", "--no-pager", "-o", "cat"],
    { encoding: "utf8", timeout: 10000 },
  ).slice(-6000);
} catch {}
const body = {
  summary: health.summary,
  stage: health.stage,
  incident,
  workflow: health.workflowUrl ?? "",
  log,
};

const payload = JSON.stringify(body);
const signature = createHmac("sha256", config.secret).update(payload).digest("hex");
try {
  const response = await fetch(config.url, {
    method: "POST",
    headers: { "content-type": "application/json", "x-t3code-channel-signature": `sha256=${signature}` },
    body: payload,
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  fs.writeFileSync(alertedPath, `${JSON.stringify({ incident: body.incident, at: new Date().toISOString() })}\n`);
  console.log(`Alerted T3 about: ${body.summary}`);
} catch (error) {
  console.log(`Couldn't alert T3 (${error.message}); the incident is still in health.json.`);
}
