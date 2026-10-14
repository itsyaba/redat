import { readFileSync, existsSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";

export const ROOT = new URL("..", import.meta.url).pathname;

function loadEnv() {
  const path = `${ROOT}.env`;
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*?)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
  }
}
loadEnv();

const env = (name: string) => {
  const v = process.env[name];
  if (!v) throw new Error(`${name} missing (put it in .env)`);
  return v;
};

export const ADDIS_KEY = env("ADDIS_API_KEY");
export const ADDIS = "https://api.addisassistant.com/api";
export const VOICE = process.env.REDAT_VOICE ?? "am-hamen";
export const MODEL = process.env.REDAT_MODEL ?? "sonnet";

export const STATE = process.env.REDAT_STATE ?? `${homedir()}/.local/state/redat`;
export const WORK = `${STATE}/work`; // claude's cwd
export const TMP = `${STATE}/tmp`; // audio scratch
export const COMMAND_LOG = `${STATE}/commands.log`;
for (const d of [STATE, WORK, TMP]) mkdirSync(d, { recursive: true });
