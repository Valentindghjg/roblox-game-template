// UserPromptSubmit hook: makes the chat classify every message for model routing
// (CLAUDE.md, "Plan, implement, verify"). Hooks cannot switch models themselves;
// the skills game-plan (Opus 5.5 high) and game-task (Sonnet 5.5) do the switch.
let raw = "";
process.stdin.on("data", (chunk) => (raw += chunk));
process.stdin.on("end", () => {
	let prompt = "";
	try {
		prompt = String(JSON.parse(raw).prompt || "");
	} catch (_) {}
	if (prompt.trim().startsWith("/")) return; // explicit slash command: nothing to add
	const context = [
		"Model routing (CLAUDE.md, owner rule). Before you answer this message, classify it:",
		"- Planning (design, decisions, spec, backlog, priorities, balancing, art direction, workflow, \"how should this work\"): invoke the skill game-plan first.",
		"- Work that changes code, tests, models or the map, or carries out a plan: invoke the skill game-task first.",
		"- Working through the backlog without stopping (\"durcharbeiten\", \"arbeite durch\", \"mach weiter\", \"weiter\", \"hustle\", \"hasseln\", \"alles abarbeiten\"): invoke the skill hasseln first.",
		"- A short question or conversation: neither skill.",
	].join("\n");
	process.stdout.write(
		JSON.stringify({ hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext: context } })
	);
});
