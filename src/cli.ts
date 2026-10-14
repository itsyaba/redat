// redat — control the ረዳት daemon.
import { connect } from "node:net";
import { spawnSync } from "node:child_process";
import { COMMAND_LOG, STATE } from "./config.ts";

const SOCKET = `${process.env.XDG_RUNTIME_DIR ?? "/tmp"}/redat.sock`;
const [cmd = "help", ...rest] = process.argv.slice(2);

const USAGE = `redat — Amharic voice assistant

  redat listen        start listening (hotkey); again = stop recording; while speaking = interrupt
  redat say <text>    run a turn from typed Amharic
  redat cancel        stop listening/speaking
  redat reset         start a new conversation
  redat status        daemon state
  redat log [-f]      commands Claude ran (JSONL)
  redat turns [-f]    turn history with timings
  redat journal       follow daemon logs
  redat daemon        run the daemon in the foreground
  redat start|stop|restart   control the systemd user service`;

function send(cmd: string, arg?: string) {
  const sock = connect(SOCKET);
  sock.once("connect", () => sock.write(JSON.stringify({ cmd, arg }) + "\n"));
  let buf = "";
  sock.on("data", (d) => (buf += d));
  sock.once("end", () => {
    const res = JSON.parse(buf);
    console.log(res.msg);
    process.exitCode = res.ok ? 0 : 1;
  });
  sock.once("error", () => {
    console.error("redat daemon is not running (redat start, or redat daemon)");
    spawnSync("notify-send", ["-a", "Redat", "ረዳት ❌", "daemon is not running — redat start"]);
    process.exitCode = 2;
  });
}

const tail = (file: string) =>
  spawnSync("tail", [...(rest.includes("-f") ? ["-f"] : []), "-n", "20", file], { stdio: "inherit" });

switch (cmd) {
  case "listen":
  case "cancel":
  case "reset":
  case "status":
  case "quit":
    send(cmd);
    break;
  case "say":
    send("say", rest.join(" "));
    break;
  case "daemon":
    await import("./daemon.ts");
    break;
  case "start":
  case "stop":
  case "restart":
    process.exitCode = spawnSync("systemctl", ["--user", cmd, "redat.service"], { stdio: "inherit" }).status ?? 1;
    break;
  case "log":
    tail(COMMAND_LOG);
    break;
  case "turns":
    tail(`${STATE}/turns.log`);
    break;
  case "journal":
    spawnSync("journalctl", ["--user", "-u", "redat", "-f", "-o", "cat"], { stdio: "inherit" });
    break;
  default:
    console.log(USAGE);
}
