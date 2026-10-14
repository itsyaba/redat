import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileP = promisify(execFile);

async function hypr(what: string): Promise<any> {
  const { stdout } = await execFileP("hyprctl", [what, "-j"]);
  return JSON.parse(stdout);
}

/** Compact snapshot of monitors and windows, prepended to each user message. */
export async function desktopSnapshot(): Promise<string> {
  try {
    const [monitors, clients, active] = await Promise.all([
      hypr("monitors"),
      hypr("clients"),
      hypr("activewindow"),
    ]);
    const mons = monitors
      .map((m: any) => `${m.name}${m.focused ? "*" : ""} ws=${m.activeWorkspace.id}`)
      .join(", ");
    const wins = clients
      .map(
        (c: any) =>
          `${c.address === active?.address ? "*" : " "} ${c.address} ws=${c.workspace.name} ${c.class} "${c.title.slice(0, 50)}"`,
      )
      .join("\n");
    return `[desktop] monitors (* = focused): ${mons}\nwindows (* = active):\n${wins}`;
  } catch (err) {
    return `[desktop] unavailable: ${(err as Error).message}`;
  }
}
