import { existsSync } from "node:fs";
import { readFileSync } from "node:fs";
import path from "node:path";
import { discoverSkills, loadSkill } from "agent-skills-eval";

const skillsRoot = path.resolve(import.meta.dirname, "../skills");
const skills = discoverSkills(skillsRoot);

if (skills.length === 0) {
  console.error("No skills found under", skillsRoot);
  process.exit(1);
}

let failed = 0;

for (const entry of skills) {
  const label = entry.relPath;

  try {
    const skill = loadSkill(entry.dir, { strict: true });

    const evalsPath = path.join(entry.dir, "evals", "evals.json");
    if (existsSync(evalsPath)) {
      const raw = JSON.parse(readFileSync(evalsPath, "utf8"));
      if (typeof raw.skill_name === "string" && raw.skill_name !== skill.name) {
        throw new Error(
          `evals.json skill_name "${raw.skill_name}" does not match SKILL.md name "${skill.name}"`,
        );
      }

      for (const [index, evalCase] of skill.evals.entries()) {
        const files = evalCase.files ?? [];
        for (const file of files) {
          const filePath = path.join(entry.dir, file);
          if (!existsSync(filePath)) {
            throw new Error(`evals[${index}] references missing file: ${file}`);
          }
        }
      }
    }

    console.log(`ok ${label}`);
  } catch (error) {
    failed += 1;
    const message = error instanceof Error ? error.message : String(error);
    console.error(`fail ${label}: ${message}`);
  }
}

if (failed > 0) {
  process.exit(1);
}

console.log(`Validated ${skills.length} skill(s).`);
