import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

function run(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8", stdio: "pipe" });
  if (result.error) {
    throw new Error(`Failed to run ${command}: ${result.error.message}`);
  }
  if (result.status !== 0) {
    const stderr = String(result.stderr || "").trim();
    throw new Error(
      `Command failed (${result.status}): ${command} ${args.join(" ")}${stderr ? `\n${stderr}` : ""}`
    );
  }
}

function quotePowerShellLiteral(input) {
  return `'${input.replace(/'/g, "''")}'`;
}

export function extractZipArchive(zipPath, destination) {
  if (process.platform === "win32") {
    const script = `Expand-Archive -LiteralPath ${quotePowerShellLiteral(zipPath)} -DestinationPath ${quotePowerShellLiteral(destination)} -Force`;
    const attempts = ["powershell", "pwsh"];
    let lastError = null;
    for (const command of attempts) {
      const result = spawnSync(
        command,
        ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script],
        { encoding: "utf8", stdio: "pipe" }
      );
      if (!result.error && result.status === 0) return;
      const stderr = String(result.stderr || result.stdout || "").trim();
      lastError = result.error
        ? new Error(`Failed to run ${command}: ${result.error.message}`)
        : new Error(
            `Command failed (${result.status}): ${command} -NoLogo -NoProfile -NonInteractive -Command ...${stderr ? `\n${stderr}` : ""}`
          );
    }
    throw lastError ?? new Error("Unable to extract zip archive on Windows.");
  }

  run("unzip", ["-q", "-o", zipPath, "-d", destination]);
}

export async function downloadArchive(url, destinationPath) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Download failed (${response.status} ${response.statusText})`);
  }
  const bytes = Buffer.from(await response.arrayBuffer());
  fs.writeFileSync(destinationPath, bytes);
}

export function stripExtractedPrefix(destination, stripPrefix) {
  const prefixParts = Array.isArray(stripPrefix) ? stripPrefix : [stripPrefix];
  const sourceRoot = path.join(destination, ...prefixParts);
  if (!fs.existsSync(sourceRoot)) return false;

  for (const entry of fs.readdirSync(sourceRoot)) {
    fs.renameSync(path.join(sourceRoot, entry), path.join(destination, entry));
  }

  fs.rmSync(path.join(destination, prefixParts[0]), { recursive: true, force: true });
  return true;
}
