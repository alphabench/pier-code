# FAQ

### Does Pier run locally?

Yes. The CLI runs as a single binary on your machine. In local-only mode your code never leaves your environment; cloud model calls are opt-in and clearly indicated.

### Which languages and frameworks are supported?

Any text-based codebase: TypeScript, Python, Go, Rust, Java, and more. It learns your project's conventions rather than assuming a stack.

### Can I prompt in Indian languages?

Yes. You can describe tasks in English, Hindi, Tamil, Kannada, Telugu and others. It reasons over your intent regardless of the language you type in. See [languages.md](./languages.md).

### What plans are available?

**Pro** is $5 a month and gives you the full Pier agent: multi-repo context, Indian-language prompting, and the option to plug in a frontier model for hard tasks. It comes with a monthly pool of usage credits that covers typical day-to-day coding. **Max** is $20 a month — everything in Pro with a much larger credit pool (~4×) for full-time, high-volume use. See [pricing.md](./pricing.md).

### What happens if I run out of credits?

Buy a $5 usage pack any time, even mid-session. Packs stack, charge the same per-token rates as Pro, and the credits don't expire — so you only pay for what you actually use beyond the monthly pool.

### How can Pier be this much cheaper?

Sovereign Indian models are trained and hosted in Bharat and priced far below frontier US models. A coding agent reads far more than it writes, so those input savings compound across every repo read, diff, and tool result.

### Is a cheaper model good enough for real coding?

For everyday work — planning, codebase Q&A, refactors, test fixing — sovereign Indian models hold their own. For the hardest long-horizon repo tasks you can plug in a frontier model per run, so you only pay frontier prices when you actually need frontier quality.

### What does Pier send off my machine?

Only the model prompt for the calls a task actually needs: the slices of code, diffs, and tool output the agent reads to reason about your task, sent to the model provider over TLS. In local-only mode nothing leaves your machine. Cloud calls are opt-in and clearly indicated before they run.

### Is my code stored on your servers?

No. Pier does not retain your source code on our servers. Prompts are processed to generate a response and are not used to train models. Account and billing data is the only thing we keep, and you can request its deletion at any time.
