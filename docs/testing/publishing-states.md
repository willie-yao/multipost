# Publishing evidence and recovery states

Caption stores local attempt evidence independently for X and Bluesky. Instagram
stores a separate prepared package and assisted-sharing history. No startup,
return, connectivity observation, refresh, Check, or browser return sends a post.
Production X/Bluesky capability and connection acceptance gates remain unavailable.
The real official publisher adapters are explicitly composed, but these gates
must be accepted separately before live use.

| State | Visible meaning and deliberate next action | Local verification |
| --- | --- | --- |
| First connection / unavailable | Drafting works without an account. Setup copy does not promise usable publishing; Accounts explains its actual unavailable gate. | Accounts, Choose, Library host suites |
| Connecting / cancelled / expired | Official connection flow is explicit; cancellation retains drafts, expiry offers reconnect. Credential-storage failure offers scoped repair. | Accounts connection and screen suites |
| No media / missing media / loading | Review distinguishes no media from unresolved/missing/damaged owned files; repair targets only the chosen version. Loading is never publication. | Review/media suites |
| Requirements unavailable | Keep the exact saved version and review again. No unverified profile or native counter enables publication. | Capabilities/Review suites |
| Save failure | Keep unsaved content, block publication/navigation until saved or explicitly recovered. Offline “saved” copy requires durable Saved state. | Draft/session/Review suites |
| Offline / network unverified | Fresh Android active-network observation: no active network is offline; validated internet is availability only; missing capabilities/errors are unverified. Review again explicitly refreshes it. Nothing auto-sends on return. | Publishing boundary and Review refresh tests; native fixture observes only |
| API access / credit / rate limit | Definite failure includes the reason; rate limits retain provider retry time. Retry reviews only the eligible failed destination and cannot pass the time gate early. | Provider/coordinator suites |
| Partial success | Each destination has its own evidence and actual frozen caption. A successful destination is never selected by a failed destination retry. | Results/retry/coordinator suites; synthetic native capture |
| Unknown | “Check [destination]”, “I found the post”, and “Send again…”; no ordinary Retry. Check is read-only and opens an exact official post or frozen profile only after an explicit action. Browser return leaves evidence unchanged. | Results/boundary/coordinator suites; synthetic native capture |
| Explicit Unknown resend | Send again opens a separately saved scoped review with visible duplicate warning. After reviewing, one final duplicate-risk dialog must be accepted before send. Acceptance is never saved or defaulted true; returning/restarting requires the final decision again. | Coordinator explicit-risk tests; Results action test; final risk dialog remains part of native/R1 navigation acceptance |
| Pending / processing | Shows the frozen version. Check status can discover readiness; only “Continue publishing [destination]” may send. | Coordinator/Results suites |
| Provider Published | Provider evidence, locally formatted confirmation time and exact validated official link come first; View reviewed version reveals its actual frozen caption/media. Never inferred from an upload, browser return or local package. | Repository/provider/Results suites |
| User reported | “You marked this as posted · not verified by the app.” No fabricated provider receipt/link. | Repository/coordinator/Results suites |
| Multiple receipts | The effective confirmed source is shown first; all confirmed publications expose their own frozen captions/media through a disclosure, with concise local times and links. History appears only when earlier attempts exist; the two current root destination rows are not repeated. | Results/repository suites |
| Instagram preparation error / ready | Explicit Continue preparation reuses the group operation/package. A ready package opens its existing assisted flow. Journaled successful Instagram-only preparation opens that local screen directly, with stored Results underneath for Back; mixed/pending/failed preparation stays on Results. The compact Instagram row leaves caption/media to that assisted screen. Instagram never uses direct-provider Published. | Coordinator/package/Results suites |
| Instagram marked / Undo | Manual local confirmation stays unverified. Persistent Undo remains in the retained package record after draft deletion/disconnect; linked packages appear once in Library. | Instagram suites and Library reconciliation tests |

A source draft ID can submit only one group. Submitted drafts reopen their stored
results even after local source edits; a deliberate new post starts with a new
ID. A failed-version edit has its own normal saved Draft with immutable nullable
`retryParentAttemptId` and `retryOperationId` fields, saved atomically with its
content. Legacy payloads omit null fields and retain their exact round trip.
The retry ID is derived from its parent, so concurrent opens share one edit;
collisions are validated, never overwritten. Explicit Retry restores a soft-deleted
unfinished edit with its saved words. Ordinary confirmation rejects recovery-owned
drafts; retry checks the exact parent, selected destination and stable operation
inside its existing transaction. No generic workflow or background job exists.

The native fixture uses isolated temporary SQLite/media, synthetic images and fake
publishers only. Its local captures are native Flutter layout/protocol evidence,
not real X/Bluesky/Instagram acceptance. Native Flutter screenshots taken under runtime Skia verify widgets only. The first-pass ADB full-frame capture is invalid because integration surface conversion retained a stale ImageView strip. A second bounded capture window precedes conversion; it does not accept shared Back/safe-area behavior. Shared leading Back/top safe-area/first-run composition, final matrix, minimum-OS/device rendering, TalkBack,
production-default renderer, live entitlement/connection and receiving-app checks
must be separately recorded in R1. Never create a live duplicate to test Unknown.
