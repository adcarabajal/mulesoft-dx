# Omni Gateway skill evals

Evaluations for the `omni-gateway` skill bundle. They answer two questions the
[evaluating-skills guide](https://agentskills.io/docs/evaluating-skills) calls out:

1. **Does the skill trigger when it should — and stay quiet when it shouldn't?**
   A skill that never fires is dead weight; one that fires on unrelated prompts
   is noise. Each case below is tagged `should_trigger: true|false`.
2. **Given the skill fired, does the agent do the right thing?** The `assertions`
   capture observable behaviors we expect in the response or tool calls.

These are a scaffold, not a harness. They are written to be run either by a human
spot-checking the bundle or by an automated grader (LLM-as-judge or string match).
Wire them into whatever runner you use; the JSON is intentionally runner-agnostic.

## Files

- `evals.json` — the eval cases, grouped by the skill each one targets.

## Schema

`evals.json` is `{ "skill": "<bundle>", "cases": [ <case>, ... ] }`. Each case:

| Field | Type | Meaning |
|-------|------|---------|
| `id` | string | Stable identifier, kebab-case, unique within the file |
| `target_skill` | string | The sub-skill this case exercises (or `none` for negative triggers) |
| `prompt` | string | The user message handed to the agent |
| `should_trigger` | boolean | Whether `target_skill` is expected to activate |
| `context` | string\|null | Optional setup (files present, prior state) the grader should stage |
| `assertions` | string[] | Observable expectations on the agent's response/tool use |
| `anti_assertions` | string[] | Behaviors that, if present, fail the case (e.g. "runs `make up` without confirming") |

## Methodology notes

- **Baseline (`without_skill`) vs `with_skill`.** For the trigger cases, run the
  prompt with the bundle disabled to confirm the behavior actually comes from the
  skill and not the base model. The guide calls this the most important control.
- **Safety assertions are first-class.** Several cases assert the agent *does not*
  autonomously run billable or destructive operations (`make up`, `make down`,
  `prepare-registration FORCE=1`). These are the highest-value checks in the set —
  a regression here costs real money.
- **Trigger-rate over single runs.** Activation is probabilistic. Run each trigger
  case several times and track the rate, rather than treating one pass as proof.
- **Keep prompts realistic.** Phrasings mirror how an operator would actually ask,
  including vague ones ("the gateway is throwing 503s") that should still route.

## Running (suggested)

There is no bundled runner yet. A minimal manual loop:

1. Enable only the `omni-gateway` bundle.
2. For each case, paste `prompt` (after staging any `context`).
3. Score `should_trigger` and each `assertion` / `anti_assertion`.
4. Repeat trigger cases 3–5× to estimate activation rate.

When a programmatic runner is added, it should consume `evals.json` directly.
