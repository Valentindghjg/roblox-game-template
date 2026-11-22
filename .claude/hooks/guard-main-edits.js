// PreToolUse hook (Edit|Write|NotebookEdit): the main chat only orchestrates, so it may
// not write game code, tests, assets or task plans itself. Subagents (input carries
// agent_id) are allowed. Set GAME_ALLOW_MAIN_EDITS=1 to switch the guard off.
const path = require("path");
let raw = "";
process.stdin.on("data", (chunk) => (raw += chunk));
process.stdin.on("end", () => {
	let input;
	try {
		input = JSON.parse(raw);
	} catch (_) {
		return; // unreadable input: do not block
	}
	if (input.agent_id || process.env.GAME_ALLOW_MAIN_EDITS === "1") return;
	const target = (input.tool_input && (input.tool_input.file_path || input.tool_input.notebook_path)) || "";
	if (!target) return;
	const root = process.env.CLAUDE_PROJECT_DIR || input.cwd || process.cwd();
	const rel = path.relative(root, path.resolve(root, target)).split(path.sep).join("/").toLowerCase();
	const guarded = ["src/", "tests/", "assets/", "docs/plans/"];
	if (rel.startsWith("..") || !guarded.some((prefix) => rel.startsWith(prefix))) return;
	process.stdout.write(
		JSON.stringify({
			hookSpecificOutput: {
				hookEventName: "PreToolUse",
				permissionDecision: "deny",
				permissionDecisionReason:
					"Model routing (CLAUDE.md): the main chat does not write code, tests, assets or plans itself. " +
					"Use the skill game-task (it starts planner, implementer, modeler and reviewer agents with their pinned models).",
			},
		})
	);
});
