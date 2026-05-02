# Udemy Practice Test — All Questions & Answers

**Total questions:** 60

---

## Question 58

**The bug prompts was detailed. What is the architectural fix?****

- **A.** *A.** Increase the extended thinking budget to give the model more reasoning capacity for review.
- **B.** *B.** Have the model review the code twice in the same session for a second opinion.
- **C.** *C.** Add more specific criteria to the review prompt for the bug categories that were missed.
- **D.** *D.** Use a separate independent Claude session without the generation reasoning context to perform the review.

---

## Question 60

**A developer's experimental MCP server should not affect teammates who clone the repository. Where should it be configured?**

- **A.** In a feature branch of the project .mcp.json that is never merged to main.
- **B.** In ~/.claude.json (user-scoped configuration), which is never shared via version control.
- **C.** In a .mcp.experimental.json file added to .gitignore.
- **D.** In the project .mcp.json with a comment marking it as experimental and instructions to ignore

---

## Question 1

**Subagent A reports '35% adoption' and Subagent B reports '60% adoption' for the same market. What is the correct synthesis approach?**

- **A.** Report only the lower value to be conservative and reduce overconfidence

---

## Question 2

**Your project CLAUDE.md contains general coding standards. You want additional rules that apply only to files matching tests/**/*.spec.ts. What is the correct approach?**

- **A.** Add a conditional section in CLAUDE.md with a comment saying 'apply these rules to test files only.'
- **B.** Create a rule file in .claude/rules/ with YAML frontmatter specifying paths: ['tests/**/*.spec.ts'].
- **C.** Create a CLAUDE.md inside the tests/ directory — it will scope naturally to that directory.
- **D.** Add the test rules to CLAUDE.md under a heading '## Test Files Only' to signal the scope.

---

## Question 3

**Three separate query() calls are made in the same script to process three different customer complaints. What state is shared?**

- **A.** All three calls accumulate in one persistent session — context compounds across calls.
- **B.** Sessions persist for 30 minutes; calls within that window share state automatically.
- **C.** The second and third calls inherit the tool results from the first call automatically.
- **D.** Each query() call creates a completely independent session with no shared state.

---

## Question 4

**Your CLAUDE.md contains @import ./standards/python-style.md but the file does not exist. What happens?**

- **A.** Claude Code automatically creates an empty python-style.md file at that path.
- **B.** The @import directive is silently skipped and the rest of CLAUDE.md loads normally.
- **C.** Claude Code throws a fatal error and refuses to start the session.
- **D.** The entire CLAUDE.md fails to load if any @import cannot be resolved.

---

## Question 5

**Your invoice extraction schema has nested line_items where the model confuses unit_price with total_price. The most effective fix is:**

- **A.** Add detailed descriptions to each nested field explaining exactly what value each represents.
- **B.** Add a computed total_price = quantity × unit_price field as a validation hint.
- **C.** Add 'do not confuse unit_price with total_price' to the system prompt.
- **D.** Flatten the schema — remove nesting entirely to eliminate field confusion.

---

## Question 6

**Your coordinator spawns 50 extraction subagents simultaneously causing API rate limit errors. What is the correct fix?**

- **A.** Switch to purely sequential processing — parallelism is not suitable for extraction tasks.
- **B.** Process all 50 invoices in a single subagent to eliminate coordination overhead.
- **C.** Cap simultaneous subagents using a semaphore or queue with a concurrency limit.
- **D.** Reduce the total number of invoices processed to 5 maximum per coordinator run.

---

## Question 7

**Your extraction tool returns {"error": true, "code": 422} for a missing required field. What is the primary problem with this error response?**

- **A.** HTTP status code 422 is not a valid code in the tool response protocol.
- **B.** The error field should be a string, not a boolean value.
- **C.** The error lacks an errorCategory field — the model cannot distinguish validation from execution failure.
- **D.** The error response should include a full stack trace to enable debugging.

---

## Question 8

**Your extraction pipeline must call extract_schema before any classification tool. Which tool_choice setting guarantees this?**

- **A.** 'any' is faster than 'auto' because it bypasses tool selection logic entirely.
- **B.** 'auto' — it allows the model to select tools freely, typically choosing the most relevant first.
- **C.** 'required' — it forces use of a single specific tool, enforcing the ordering constraint programmatically.
- **D.** 'any' — it guarantees the model calls at least one tool per turn, preventing pure text responses.

---

## Question 9

**A skill for generating API documentation produces 4,000 tokens of intermediate reasoning you want to discard from the main context. Which frontmatter key controls this?**

- **A.** isolation: subagent
- **B.** verbosity: low
- **C.** context: fork
- **D.** output: final-only

---

## Question 10

**SubagentStart and SubagentStop hooks are configured in a multi-agent Developer Productivity system. What is their primary purpose?**

- **A.** They provide subagents with read access to the full coordinator context window on spawn.
- **B.** They automatically retry failed subagents after a 5-second delay without coordinator involvement.
- **C.** They fire when subagents are spawned and complete, enabling the coordinator to track lifecycle events.
- **D.** They allow subagents to communicate directly with each other without going through the coordinator.

---

## Question 11

**Your tool get_customer_profile accepts a customer_id string, but the model frequently passes email addresses. What is the most effective fix?**

- **A.** Rename the parameter to customer_numeric_id to signal the expected type.
- **B.** Create a separate get_customer_profile_by_email tool for email-based lookups.
- **C.** Add validation that rejects non-numeric customer IDs with an error.
- **D.** Update the tool and parameter descriptions to explicitly state the expected format and example value.

---

## Question 12

**You submitted a batch of 300 research documents. Processing finished but some have errors. What is the correct way to identify failed requests?**

- **A.** Manually review all 300 results to identify failures by inspection.
- **B.** Download all 300 results and filter programmatically for non-success statuses.
- **C.** Cancel the batch and resubmit all 300 documents to ensure clean results.
- **D.** Query the batch results using the custom_id field to filter by errored status.

---

## Question 13

**Your agent must always call verify_identity before process_payment, but logs show verify_identity is sometimes skipped. What is the correct fix?**

- **A.** Add 10 few-shot examples to the system prompt demonstrating verify_identity called first.
- **B.** Implement a programmatic prerequisite: process_payment checks for a verified identity token before executing.
- **C.** Bold the verify_identity rule in the system prompt with emphasis markers.
- **D.** Log every skipped verification for retroactive human review and correction.

---

## Question 14

**Your pipeline automates high-confidence extractions (confidence > 0.95) without human review. Silent accuracy drift has gone undetected. The fix is:**

- **A.** Monitor model confidence score distributions — a shift would indicate accuracy drift.
- **B.** Monitor overall pipeline error rates including low-confidence extractions.
- **C.** Implement stratified random sampling specifically of the high-confidence extractions for periodic ground-truth validation.
- **D.** Increase the confidence threshold from 0.95 to 0.99 to reduce automation scope.

---

## Question 15

**Your research agent runs for 3 hours on a literature review. You run /compact midway through. What does /compact do?**

- **A.** It clears all context and resets the session to its initial state.
- **B.** It archives the current session and creates a fresh continuation session.
- **C.** It compresses verbose context (tool outputs, reasoning chains) into summaries while preserving key findings.
- **D.** It exports all findings to a file and clears the session — you must restart.

---

## Question 16

**Your project CLAUDE.md says 'use snake_case for Python variables.' A developer adds 'use camelCase for Python variables' to their personal ~/.claude/CLAUDE.md. What happens?**

- **A.** Claude Code detects the conflict and asks the developer which rule to apply.
- **B.** The project CLAUDE.md always wins — project rules override personal rules.
- **C.** The personal file always wins — user settings override project settings.
- **D.** Both files load and both rules are present in context — the model sees a conflict.

---

## Question 17

**Your .mcp.json references an MCP server at http://localhost:3000. A teammate clones the repo and the server is unavailable. Why?**

- **A.** The .mcp.json format does not support localhost URLs at all.
- **B.** The .mcp.json must be re-committed after cloning for the configuration to activate.
- **C.** The MCP server is not running on the teammate's machine — localhost refers to their local machine.
- **D.** The teammate must add the server to their ~/.claude.json file to activate it.

---

## Question 18

**When a Claude Code session ends, which hook fires to allow you to perform cleanup tasks such as logging session duration?**

- **A.** SessionClose
- **B.** SessionEnd
- **C.** PostSession
- **D.** Stop

---

## Question 19

**After 3 retries with exponential backoff, an API call still fails. The max retry count is exhausted. What is the correct next step?**

- **A.** Return a generic 'service unavailable' message to the customer and close the session.
- **B.** Surface the failure to a human agent with full error context via the escalation path.
- **C.** Switch to a different Claude model version and replay the same message sequence.
- **D.** Retry 10 more times with a fixed 5-second delay to exhaust all recovery options.

---

## Question 20

**Your extraction prompt uses a schema where vendor_name is required. For invoices with no vendor, the model returns 'Unknown Vendor' instead of null. Why?**

- **A.** A post-processing step should replace 'Unknown Vendor' with null after extraction.
- **B.** The model is hallucinating — add 'do not guess vendor names' to the prompt.
- **C.** Switch from tool_use to a text-based extraction approach for optional fields.
- **D.** The required field forces the model to return something even when data is absent — make it nullable.

---

## Question 21

**You want Claude Code to automatically load a project summary every time a new session starts without requiring developer action. What is the correct approach?**

- **A.** Use a SessionStart hook to inject the summary programmatically at session start.
- **B.** Add the summary to each developer's personal ~/.claude/CLAUDE.md.
- **C.** Add the summary to a skill with context: fork so it loads fresh each session.
- **D.** Place the project summary in CLAUDE.md — it loads automatically at session start.

---

## Question 22

**Your agent must escalate to a human when it cannot resolve a customer issue. What should the handover package include?**

- **A.** Customer ID, root cause analysis, what was ruled out, recommended next steps, and sentiment.
- **B.** Only the customer name and account number — human agents prefer to investigate fresh.
- **C.** The full raw conversation transcript including all tool call results and system prompts.
- **D.** A sentiment score and predicted customer satisfaction rating with no other context.

---

## Question 23

**Your tool sets isError: true for every non-200 response including business outcomes like 'credit limit reached'. What is wrong?**

- **A.** Reserve isError: true for execution failures only; use isError: false with a typed result field for business outcomes.
- **B.** Return HTTP 200 for all responses so the coordinator never encounters isError.
- **C.** Add a separate isBusinessError flag alongside isError for business-logic outcomes.
- **D.** Change the coordinator to ignore all isError responses and use content fields instead.

---

## Question 24

**A subagent encounters a 'permission denied' error calling an internal API. Should it retry?**

- **A.** Yes — retry once, then escalate if the second attempt also fails.
- **B.** No — discard the error silently and return an empty result to avoid disrupting the pipeline.
- **C.** No — permission denied is non-retryable; propagate the structured error to the coordinator.
- **D.** Yes — retry all errors with exponential backoff since permissions can be transient.

---

## Question 25

**You need to prevent Claude Code from running database migration commands in automated CI sessions. Where should this restriction be configured?**

- **A.** In a settings.json file setting allowedTools to exclude the Bash tool in CI environments.
- **B.** In the root CLAUDE.md as a natural language rule: 'never run database migrations in CI!'
- **C.** In the CI pipeline script — wrap Claude Code invocations in a restricted shell environment.
- **D.** By removing database credentials from CI so migration attempts fail at the execution level.

---

## Question 26

**Your CI/CD pipeline uses a PreCompact hook. Which event correctly describes when it fires?**

- **A.** Before any tool call is made, allowing inspection of tool arguments.
- **B.** Before each new user message is sent to the model for processing.
- **C.** Before the model commits code changes to the version control repository.
- **D.** Before the conversation context window is compacted, allowing the hook to inject a summary.

---

## Question 27

**The Claude Agent SDK's query() function was previously named something different. What was the original name?**

- **A.** Claude Code SDK
- **B.** Claude Agentic SDK
- **C.** Claude Orchestration SDK
- **D.** Claude Tasks SDK

---

## Question 28

**Your MCP product search tool accepts a single query string. The model constructs poorly formed queries. What is the best fix?**

- **A.** Decompose the input schema into structured fields like keyword, category, and price_range.
- **B.** Return an error when the query string is shorter than 10 characters.
- **C.** Make the query parameter optional so agents can call the tool without it.
- **D.** Add a strict_mode boolean that enables query validation within the tool.

---

## Question 29

**Your code review produces findings that developers reject 80% of the time as too vague. Which single addition most improves acceptance?**

- **A.** A severity field (critical/high/medium/low) for each finding.
- **B.** A remediation field providing the specific code change that would fix the issue.
- **C.** A category field classifying the type of bug (null_safety, type_error, etc.).
- **D.** A line_count field showing how many lines are affected by the issue.

---

## Question 30

**During a long Developer Productivity session, your agent starts recommending generic patterns rather than project-specific patterns it knew earlier. What is the cause?**

- **A.** Restart the session every 30 minutes to prevent context degradation.
- **B.** Early project-specific context has been displaced by later content in the context window.
- **C.** The session has not been compacted recently — run /compact after every 20 tool calls.
- **D.** The model needs a larger context window — switch to a model with extended context.

---

## Question 31

**Subagent A reports 'market grew 15%' and Subagent B reports 'market grew 22%' for the same metric. What structured field prevents this ambiguity?**

- **A.** Word count of the source document for each finding.
- **B.** A required data_period field specifying the year or date range each figure applies to.
- **C.** A source credibility rating for each subagent's report.
- **D.** A confidence score for each finding.

---

## Question 32

**Subagents return four prose paragraphs of findings. The synthesis agent cannot reliably link claims back to source documents. The fix is:**

- **A.** Add 'always cite your sources' to the synthesis agent's system prompt.
- **B.** Add a post-synthesis citation matching step using semantic similarity.
- **C.** Have the synthesis agent search for source references in the prose after synthesis.
- **D.** Require subagents to output structured claim-source mappings: each finding paired with its source reference.

---

## Question 33

**Your MCP server exposes resources (read-only schemas) alongside tools. The model never uses the resources. What is the likely cause?**

- **A.** Resources require a separate API call and cannot be used in the same session as tools.
- **B.** The model always prefers tools over resources because tools return live dynamic data.
- **C.** The resource descriptions do not clearly explain what data they contain and when to use them.
- **D.** MCP resources are not accessible to Claude agents — only tools can be called.

---

## Question 34

**Your CI pipeline runs claude -p 'Generate tests for src/auth.ts' and exits immediately with an error. What is the most likely cause?**

- **A.** The -p flag is not supported when running Claude Code inside CI environments.
- **B.** The ANTHROPIC_API_KEY environment variable is not set in the CI environment.
- **C.** The src/auth.ts file path is not accessible from the CI runner filesystem.
- **D.** Claude Code cannot generate tests without an active interactive session.

---

## Question 35

**A developer wants to interrupt a running skill mid-execution before it makes an undesired file change. What should they do?**

- **A.** Close and reopen the terminal — this safely terminates all running operations.
- **B.** They cannot interrupt a running skill — it must complete before changes can be reviewed.
- **C.** Press Escape to interrupt the skill mid-execution, halting further actions.
- **D.** Type /stop in the Claude Code interface to halt execution safely.

---

## Question 36

**A batch of 500 documents has 47 failures with error_max_structured_output_retries. What does this error indicate?**

- **A.** The batch API rate limit was exceeded causing 47 requests to fail with retries exhausted.
- **B.** The model attempted to produce structured output conforming to the schema but exhausted retry attempts.
- **C.** The documents exceeded the maximum file size for batch processing.
- **D.** The structured output beta feature is not available for batch processing at this scale.

---

## Question 37

**Your agentic loop receives stop_reason: 'max_tokens' from the API mid-task. The agent has already called lookup_order. What should it do?**

- **A.** Retry the last API call immediately with the same messages array and max_tokens setting.
- **B.** Discard the partial result and restart the full task from the initial user message.
- **C.** Treat it as a fatal error, log the failure, and notify the customer the request cannot be completed.
- **D.** Summarise progress, add a continuation message to the conversation, and resume work where it stopped.

---

## Question 38

**A PostToolUse hook receives a sentiment_analysis tool result showing extreme negative sentiment. What is the correct hook action?**

- **A.** Modify the tool result to neutral before passing it to the model to avoid bias.
- **B.** Append escalation metadata to the tool result, flagging the case for priority human review.
- **C.** Terminate the session immediately and route the case to a human queue.
- **D.** Log the result and take no further action — the model will decide what to do with it.

---

## Question 39

**Your agent handles a case with three open issues: billing dispute, missing delivery, and warranty claim. It resolves two but forgets the warranty claim. The fix is:**

- **A.** Add 'remember to address all open issues' to the system prompt.
- **B.** Store all issue state in a database and query it at the start of each turn.
- **C.** Extract open issues into a structured issue tracker block with IDs, types, and statuses in context.
- **D.** Limit cases to one issue at a time and ask the customer to call back for additional issues.

---

## Question 40

**A PreToolUse hook must block process_refund calls above $500. A developer asks whether this guarantee is probabilistic or deterministic. Which is correct?**

- **A.** The guarantee is deterministic — the hook runs programmatically before the tool call.
- **B.** The guarantee depends on whether the hook returns a decision field in its output.
- **C.** The guarantee is probabilistic — the model may bypass it if the system prompt is long.
- **D.** The guarantee is deterministic only when tool_choice is set to 'any'.

---

## Question 41

**Your commit message generator produces 40% vague messages ('fixed bug'). The most effective improvement is:**

- **A.** Add a minimum character count of 50 characters for commit messages.
- **B.** Provide 3-4 few-shot examples contrasting vague messages with specific, well-formed ones.
- **C.** Add 'write specific commit messages' to the system prompt.
- **D.** Set temperature to 0 to make messages more deterministic and specific.

---

## Question 42

**Your cross-file integration pass consistently misses findings from files processed in the middle of a large batch. What is the most likely cause?**

- **A.** The cross-file pass prompt does not have enough detail about integration issues.
- **B.** The cross-file pass context window is too small to hold all per-file results.
- **C.** The cross-file pass should be run before the per-file pass to avoid bias.
- **D.** The lost-in-the-middle effect causes middle-positioned content to receive less attention.

---

## Question 43

**Your invoice extraction returns amount fields sometimes as strings ('$1,234.56') and sometimes as numbers (1234.56). The most effective fix is:**

- **A.** The model is ignoring the schema — switch to a more capable model for numeric fields.
- **B.** Add a prompt instruction: 'always return monetary amounts as plain numbers without formatting.'
- **C.** Enforce strict numeric typing in the schema and add a field description with a format example.
- **D.** Post-process all amount fields to strip currency symbols after extraction.

---

## Question 44

**Your agent ignores run_tests and uses the Bash tool instead, even though run_tests exists. What is the most effective fix?**

- **A.** Enrich the run_tests description to explain what it does differently and when to prefer it over Bash.
- **B.** Force tool_choice to always select run_tests, overriding model selection entirely.
- **C.** Remove the Bash tool from the agent's tool set to force use of run_tests.
- **D.** Rename run_tests to bash_run_tests to associate it with the Bash usage pattern.

---

## Question 45

**An agent in your CI/CD pipeline calls delete_branch unintentionally when it should have called archive_branch. What is the safest preventive measure?**

- **A.** Implement a PreToolUse hook that intercepts delete_branch calls and verifies branch protection status.
- **B.** Rename delete_branch to permanently_delete_branch_irreversible to signal destructive intent.
- **C.** Remove delete_branch from the agent's tool set and only re-add it when needed.
- **D.** Add a user confirmation prompt that requires typing 'DELETE' before the tool executes.

---

## Question 46

**Your structured output pipeline uses strict: true on tool definitions. What does this guarantee?**

- **A.** strict: true causes the API to return an error instead of a partial result on validation failure.
- **B.** strict: true increases the model's reasoning budget for more thorough schema adherence.
- **C.** strict: true allows the tool to process larger documents than standard tool_use definitions.
- **D.** strict: true enforces that the model's output strictly conforms to the JSON schema, eliminating type mismatches.

---

## Question 47

**Your MCP tool search_orders returns all order fields. You need a lightweight version returning only summary fields. What is the best approach?**

- **A.** Create a new search_orders_summary tool alongside the existing one, with distinct descriptions.
- **B.** Deprecate search_orders and require all callers to migrate to the new tool immediately.
- **C.** Modify search_orders to return summary fields only, removing the full detail response.
- **D.** Add a 'summary_only' boolean parameter to the existing search_orders tool.

---

## Question 48

**Your CI/CD code review agent flags TODOs in test files as errors, causing 60% false positives. The most effective fix is:**

- **A.** Define explicit inclusion and exclusion criteria: flag TODOs in non-test paths only.
- **B.** Remove TODO detection entirely since the false positive rate is too high.
- **C.** Add 'be strict about TODO detection' to the review system prompt.
- **D.** Add few-shot examples showing correct TODO detection in production versus test code.

---

## Question 49

**A customer wants to transfer to a human agent despite the agent having already solved their issue. What is the correct agent behaviour?**

- **A.** Honour the customer's explicit preference immediately and initiate the transfer.
- **B.** Resolve the question first then offer the transfer — the interaction will be brief.
- **C.** Ask the customer why they prefer a human to assess whether escalation is truly needed.
- **D.** Answer the question first to demonstrate helpfulness, then initiate the transfer.

---

## Question 50

**Your multi-agent research coordinator needs to search three independent databases simultaneously. Which approach is correct??**

- **A.** Sequential only if each search takes more than 10 seconds to ensure resource safety.
- **B.** Parallel only for the first two, then sequential for the third to balance load.
- **C.** Sequential — so each subagent can see prior results before starting its own search.
- **D.** Parallel — emit all three Task tool calls in the same coordinator response turn.

---

## Question 51

**Your contracts have an optional arbitration_clause with three sub-fields. When absent, the model returns the parent object as null but sub-fields as empty strings. The fix is:**

- **A.** Make all three sub-fields required strings with 'N/A' as the fallback value.
- **B.** Model arbitration_clause as a nullable object; when absent return null for the parent only.
- **C.** Use three separate top-level nullable fields to eliminate nesting.
- **D.** Make arbitration_clause a required object with all three sub-fields required.

---

## Question 52

**You need to correlate batch results back to records in your database. What is the correct approach?**

- **A.** Include the database record ID in the prompt and parse it from the model's text response.
- **B.** Assign a unique custom_id to each request matching your database record identifier.
- **C.** The API automatically returns results in the same order as submitted requests.
- **D.** Use the batch_id returned by the API to look up individual results by position.

---

## Question 53

**Your team has CLAUDE.md at the project root and another CLAUDE.md inside src/api/. A developer works in src/api/. What loads?**

- **A.** Only the root CLAUDE.md — subdirectory CLAUDE.md files are always ignored.
- **B.** Both the root and src/api/ CLAUDE.md files load — both contribute rules to the session.
- **C.** Whichever CLAUDE.md was most recently modified by any team member.
- **D.** Only the src/api/CLAUDE.md — the most specific file takes precedence and the root is excluded.

---

## Question 54

**Your multi-agent coordinator's context window fills up from four subagents returning lengthy results. What is the best solution?**

- **A.** Reduce the number of subagents from four to two to halve context consumption.
- **B.** Have subagents communicate results directly to each other instead of the coordinator.
- **C.** Increase the coordinator's max_tokens to allow a longer context window.
- **D.** Instruct subagents to return highly compressed structured summaries with full results written to files.

---

## Question 55

**Your SKILL.md has disable-model-invocation: true in its frontmatter. What is the effect?**

- **A.** The skill runs in read-only mode, preventing any file writes during execution.
- **B.** The skill executes using only deterministic tool calls without invoking the language model.
- **C.** The skill is prevented from calling external tools or MCP servers.
- **D.** The skill runs but all model outputs are discarded — only tool results are returned.

---

## Question 56

**A Task tool subagent returns error_during_execution when reviewing a 500-line Python file. What is the most likely cause?**

- **A.** The subagent was killed by the coordinator's task-level timeout configuration.
- **B.** The model only reviews files up to 200 lines by default per execution policy.
- **C.** The subagent exhausted its context limit processing the file plus its own reasoning.
- **D.** The Task tool has a hard 200-line file size limit enforced by the API.

---

## Question 57

**A multi-document research synthesis of 6 summaries consistently omits findings from summaries 3 and 4. What is the most likely cause?**

- **A.** Summaries 3 and 4 contain conflicting information the model chose to omit.
- **B.** The synthesis prompt does not explicitly instruct the model to include all summaries.
- **C.** The subagents for summaries 3 and 4 produced lower-quality output.
- **D.** The lost-in-the-middle effect causes summaries in middle positions to receive less attention.

---

## Question 59

**A UserPromptSubmit hook contains logic that takes 75 seconds to complete. What happens when it fires?**

- **A.** The entire Claude Code session is terminated and must be restarted manually.
- **B.** The hook executes but its return value is discarded if it exceeds 30 seconds.
- **C.** The session waits indefinitely — UserPromptSubmit hooks have no timeout.
- **D.** The hook is terminated after 60 seconds and the session proceeds without its output.

---
