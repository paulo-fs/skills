# Frontend review lenses

Load only the sections relevant to the patch. Apply the shared evidence gate: supported user action → actual state/data path → regression → impact. Use the project's framework and library versions; React terminology below illustrates mechanisms rather than mandating a stack.

## State, async work, and lifecycle

- Trace state ownership, props, derived values, subscriptions, and effects through the actual component tree. Check whether changed dependencies capture stale values, trigger loops, or miss a required update.
- Construct a concrete ordering for races: request A starts, context changes, request B completes, then A overwrites B. Inspect cancellation, request identity, query-library guarantees, and component lifetime before flagging it.
- Check cleanup of listeners, observers, timers, and subscriptions that can outlive the intended owner. An uncancelled promise is not automatically a leak or visible bug.
- Inspect keys and identity when lists reorder or conditional branches change. Prove which input, selection, or local state is lost or assigned to another item. Index keys are not inherently wrong for a stable, stateless list.
- Distinguish a deliberate state reset from accidental remounting. Do not flag development-only double execution as a production defect without checking the framework's lifecycle semantics and actual side effects.

## Forms and submission

Trace API value → hydration/defaults → displayed field → validation/transform → submitted payload → server response → reset/refetch.

- Exercise create, edit without changes, partial edit, clearing optional fields, and reopened forms. Check empty/null/undefined, dates, percentages, minor units, enums, and disabled versus omitted inputs.
- Verify that a background refetch/reset does not overwrite dirty values or that the intended conflict policy handles it. Check switching the edited entity while a request is pending.
- Inspect native submit, Enter, button types, pending state, retries, and server idempotency before claiming duplicate writes. Disabling a button is not a guarantee of exactly-once processing.
- Follow validation failures and asynchronous server errors to visible, associated feedback. Ensure the user can correct and retry without silently losing data.
- Test through the rendered form with the raw API response and actual transform/resolver where they are the disputed boundary; calling a submit helper with a prebuilt payload hides conversion bugs.

## Rendering, SSR, and server/client boundaries

- Compare initial server and client output for changed locale, timezone, random IDs, time-dependent values, and browser-only APIs. Establish that SSR actually runs for the route before reporting a hydration issue.
- Check serializable props and module boundaries. Follow imports to determine whether privileged code, credentials, or unintended dependencies reach the browser bundle.
- Inspect loading, suspended, error, empty, and partial-data branches for reachable states; do not require every component to implement every state when its parent already owns them.
- Verify framework-specific guarantees before proposing memoization, client directives, effect rewrites, or suppression of hydration warnings. A warning suppression is not proof that the underlying mismatch is harmless.

## Client cache and navigation

- Trace query/cache keys to every parameter that changes results: tenant, user, filters, pagination, locale, or currency as applicable. Check whether cached data can cross an identity/context boundary.
- Follow mutations to invalidation, optimistic updates, rollback, and refetch ordering. Check failure after an optimistic update and switching entities during an in-flight mutation.
- Exercise URL/query parameters, deep links, back/forward, refresh, and filter/page resets when changed. Do not assume in-memory state matches browser history.
- For auth-dependent UI, inspect logout/session changes and sensitive cache lifecycle. A hidden button or client route guard is not server authorization; inspect the server contract before claiming an exploitable bypass.

## Accessibility and interaction

- Verify semantic elements, accessible names, labels, error associations, and actual keyboard operation for changed controls. Inspect wrapper components before claiming they omit attributes or behavior.
- For dialogs, menus, and overlays, follow opening focus, navigation, Escape/dismissal, background interaction, and focus restoration, using the appropriate interaction pattern rather than one universal focus rule.
- Check whether changes make an action unavailable to keyboard or assistive-technology users. Set priority by the blocked task and available recovery; accessibility defects are not automatically cosmetic/P3.
- Automated accessibility checks support specific assertions but do not prove complete accessibility. A screenshot cannot establish keyboard behavior, focus order, accessible names, or screen-reader announcements.

## Layout, content, and internationalization

- Use supplied designs, existing behavior, supported breakpoints, and explicit design-system conventions as the expectation. Do not invent a redesign or report personal visual preferences as defects.
- Exercise relevant narrow/wide viewports, zoom, long content, translated labels, validation messages, and large values. Identify clipping, obscured controls, unreadable content, or unintended scroll with a concrete affected task.
- Trace locale selection, pluralization, date/number/currency formatting, and business-timezone rules independently. A display preference must not silently change monetary units or the meaning of an expiry date.
- Inspect responsive or design-system components before alleging missing behavior. Reusing a component is not proof it works in the new composition; overriding it is not automatically a violation.

## Browser security and performance

- Trace new untrusted HTML, URL, or script sinks to sanitization and encoding; distinguish escaped text from executable markup. Follow server/client boundaries for secrets and sensitive data. Limit dependency checks to changed packages or requested audits.
- Assess added request waterfalls, rendering work, bundle imports, large lists, and expensive interactions with relevant runtime/build evidence. Re-rendering alone is not a user-visible regression.
- Do not require `useMemo`, `useCallback`, virtualization, lazy loading, or a new state library by default. Show a supported workload and cost, or an explicit violated performance budget.

## Verification and evidence

Choose the lowest-cost method that can establish the claim:

| Claim | Suitable evidence |
| --- | --- |
| Incorrect payload, stale closure, or cache key | Trace with actual library semantics; focused unit/component reproduction when useful |
| Out-of-order response overwrites current selection | Controlled async component test or browser reproduction using representative responses |
| Hydration mismatch or browser-only API error | Relevant SSR/build/runtime evidence; a DOM-only test does not reproduce server hydration |
| Clipping, responsive layout, contrast, or actual focus behavior | Browser observation/measurement at the relevant revision, state, viewport, and interaction |
| Bundle or interaction slowdown | Relevant build output, network timing, or profiler trace with workload and comparison |

For browser-dependent findings, record route, reviewed build/revision, input/state, browser/viewport, steps, expected/actual behavior, and relevant screenshot, DOM, network, console, or focus evidence. Select evidence for the assertion; do not collect every artifact for every finding. Redact sensitive content.

Use authorized local/test environments and supplied accounts/data. Follow host browser-tool instructions. If the running build cannot be tied to the reviewed revision, treat observations as exploratory until the patch connection is established. Do not infer visual correctness from class names, a lint pass, or jsdom snapshots.

If browser access is unavailable, retain statically established logic/semantic findings, but explicitly mark layout, appearance, and interactive focus as unverified. Do not fabricate screenshots or turn an unobserved suspicion into a confirmed UI regression.
