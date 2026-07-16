---
id: 2026-07-16-evaluate-herdr-as-state-backend
title: Evaluate Herdr for agent-centric workflow
state: inbox
createdAt: 2026-07-16T05:27:59.887Z
updatedAt: 2026-07-16T06:05:09.329Z
sourcePlan: 2026-07-14-design-shareable-remote-adapter-package
---

# Evaluate Herdr for agent-centric workflow

## Plan

## Objective

Decide on the work machine whether Herdr can replace the current agent-session picker and simple tmux layouts despite a private non-OpenSSH devbox connection. If Herdr cannot observe remote agents and create useful remote sidecars without substantial connector-specific glue, stop pursuing it as a runtime and carry the relevant state-management ideas into `tmux-agent-bar` instead.

The output is an evidence-backed adoption or rejection decision. Do not migrate active sessions or implement a durable bridge during evaluation.

## Resume context

The desired workflow is agent-centric, not workspace-centric:

- Several agents may run locally across different repositories.
- Each remote devbox normally has one agent.
- The current picker presents one flat list of all agent sessions and switches directly to the selected tmux session.
- A typical tmux session is deliberately simple: one agent pane, sometimes split side by side for an editor, shell, or terminal review/diff tool.
- Workspaces, host groupings, multi-agent remote projects, and elaborate layouts are not important user concepts.
- tmux remains attractive because it is universal and already sits comfortably around the private devbox connector.

The evaluation should therefore judge Herdr as a flat agent switcher with optional sidecars. Do not require the user to adopt workspace-oriented navigation merely because Herdr exposes workspaces internally.

## Preliminary findings

### UI fit

Herdr's TUI is credible for this workflow:

- The Agents panel always contains all detected agents across workspaces.
- `ui.agent_panel_sort = "priority"` can flatten attention ordering instead of grouping by workspace.
- Optional previous-agent, next-agent, and indexed agent bindings can switch directly across the agent list.
- `prefix+g` provides a searchable workspace/tab/pane tree with state filters.
- Selecting an agent focuses its workspace, tab, and pane, so workspaces can remain mostly incidental.
- Ordinary panes can be split right or down for editor, shell, test, and review sidecars.
- The sidebar can be compacted or hidden when pane width matters.
- Detach/reattach, copy mode, popups, notifications, worktree helpers, and the socket API cover more than the minimum workflow needs.

An isolated Herdr `0.7.4` smoke test confirmed that the desktop layout, searchable navigator, and navigate overlay are coherent and responsive. It did not validate daily terminal fidelity, remote integration, or long-running stability.

### `sesh` compatibility

`sesh` manages tmux sessions and requires a tmux-compatible command surface. Herdr does not implement that CLI, so `sesh connect`, session switching, startup-window configuration, and existing tmux popup integration do not transfer directly.

If Herdr is adopted, its Agents panel and session navigator should replace the switching part of `sesh`. Only recreate zoxide-based directory discovery or workspace creation if hands-on use shows that capability is still missed; do not build a general compatibility layer.

### Remote constraint

The private devbox connection is the decisive risk:

- Plain SSH started inside a local Herdr pane does not currently make the remote agent appear automatically; upstream issue `#1170` describes that gap.
- `HERDR_AGENT=<agent>` can tell Herdr to apply a known screen manifest to a host-visible wrapper process. This may work for a connector that faithfully streams one remote agent UI, but it has not been tested with the real connector.
- If one central Herdr server owns a connector pane, a new Herdr split launches on the server host. It does not automatically inherit the remote connection. A remote sidecar would need the connector to open a second session to the same devbox and launch the requested tool.
- Running a Herdr server on each devbox would make sidecars naturally remote, but each devbox becomes a separate server. Herdr does not currently aggregate multiple servers into one Agents panel; upstream issue `#334` tracks that broader direction.

Herdr is viable as a wholesale replacement only if the real connector can support both remote agent detection and same-devbox sidecar creation with very little glue.

### State and license constraints

- Claude Code and Codex state still comes from Herdr screen-manifest detection because their hooks do not author every lifecycle transition. Background waits can still look done.
- Herdr's external snapshot/event API was added recently in `0.7.2` and should be treated as promising but young.
- Herdr is AGPL-3.0-or-later or commercially licensed, while `tmux-agent-bar` is MIT. Reuse documented concepts and APIs, but do not copy Herdr implementation code without a deliberate license decision.

## Work-machine evaluation

### 1. Inspect the actual boundary

Trace one local agent session and one representative devbox agent session through:

- tmux session and pane ownership;
- connector process and invocation;
- remote agent process;
- lifecycle hooks or terminal inference;
- current state/cache writer;
- picker and sidecar launch behavior.

Keep private connector names, hostnames, paths, authentication details, and commands out of this public plan. Use an untracked work-machine note when exact details are needed.

### 2. Run the smallest Herdr feasibility test

Use an isolated, version-pinned Herdr setup without replacing tmux or existing sessions.

Test one local agent and one connector-backed devbox agent. For the connector-backed pane:

- launch the wrapper with the appropriate `HERDR_AGENT` hint;
- verify whether it appears in `agent list --json` and the Agents panel;
- verify working, blocked/question, done/idle, interrupt, exit, disconnect, and reconnect behavior;
- inspect failures with `agent explain --json`;
- confirm that stale connector output does not remain a false live agent.

Reject wholesale adoption if reliable detection needs transcript scraping, broad polling, socket forwarding, or connector recovery logic inside Herdr-specific glue.

### 3. Test flat switching and sidecars

Configure priority-sorted agents plus direct previous/next and indexed agent bindings. Confirm that switching among several local agents and the devbox agent is at least as fast as the current picker.

From the devbox agent pane, create a side-by-side editor or review pane and answer these explicitly:

- Does the split run locally or remotely?
- Can the connector reopen the same devbox non-interactively?
- Can a small launch command preserve devbox identity and working directory?
- Does disconnect/reconnect leave both panes understandable and recoverable?

Reject wholesale adoption if routine remote sidecars require a new supervisor, complex per-pane metadata, fragile connection cloning, or a second Herdr server that disappears from the unified agent list.

### 4. Decide and stop

Choose one outcome:

1. Adopt Herdr wholesale because one server can own all relevant agent panes and sidecars with minimal connector glue.
2. Keep tmux and use Herdr only as design input.
3. Consider a narrow Herdr state adapter only if its state is uniquely valuable and the adapter is simpler than improving the existing remote source.

Do not choose a hybrid merely to preserve sunk evaluation work. Prefer the smallest overall system that preserves the flat agent picker and universal session behavior.

## Fallback: harden `tmux-agent-bar` as the state platform

If Herdr fails the connector or sidecar test, return to the active `Harden public adapter platform` plan. The target architecture is:

```text
hooks and private remote adapters
              |
              v
canonical cached agent rows
         /        |        \
        v         v         v
   tmux status  fzf picker  future UI
```

The private adapter should continue to own transport, host discovery, connector behavior, remote probing, authentication, and recovery. The public core should remain launcher-agnostic and consume only normalized state.

Prioritize these Herdr-inspired improvements without copying its implementation:

- Make state authority explicit so hook, process, tail, and adapter evidence do not compete silently.
- Preserve semantic state separately from presentation. A compact renderer may display waiting/blocked like done while richer consumers retain the distinction.
- Keep stable identity separate from display labels.
- Publish `rows` and `rows-cached` as the canonical snapshot API.
- Make the status renderer, fzf picker, and future consumers share one filtering and ordering path.
- Strengthen `explain` so it reports authority, evidence, freshness, fallback, shadowing, and the selected row.
- Consider unseen completion separately from ordinary idle only if a concrete consumer needs attention state.
- Keep terminal/output observation in the PTY owner or adapter, never the renderer.

Do not add a daemon, socket protocol, event bus, JSON format, or compatibility layer unless a concrete consumer proves the simpler cached-row contract insufficient.

## Paper-cut investigation

The value of `tmux-agent-bar` depends on predictable state more than another UI. On the work machine, capture a focused reproduction for each observed paper cut and classify it before editing:

- explicit hook state;
- live process identity;
- bounded tail fallback;
- observed wrapped-session memory;
- normalized source rows;
- replacement shadowing;
- source refresh or cache timing;
- render-only filtering or ordering;
- tmux-side cached option refresh.

Use `explain-cached` when diagnosing stale cache or adapter behavior so the diagnostic does not mutate the evidence by refreshing sources. Add a focused regression test at the boundary that actually changes.

## Non-goals

- Do not migrate or terminate active tmux sessions during evaluation.
- Do not disclose private connector details in this public repository.
- Do not build a general Herdr/`sesh` compatibility layer.
- Do not add Herdr-specific logic to the core renderer.
- Do not copy AGPL implementation code into this MIT repository.
- Do not build multi-server aggregation or connector supervision merely to make Herdr fit.
- Do not implement a new UI until the underlying row/state contract is reliable enough that the UI would not inherit the current paper cuts.

## Stopping point

Stop after producing:

- a sanitized topology summary;
- a Herdr remote-detection and sidecar verdict;
- a short flat-agent-navigation scorecard;
- the selected outcome and rejected alternatives;
- focused reproductions for any `tmux-agent-bar` paper cuts discovered during inspection;
- a separate migration plan only if Herdr wholesale adoption is selected.

If Herdr is rejected, checkpoint the evidence here and resume the existing `Harden public adapter platform` plan rather than creating a duplicate implementation plan.

## Verification

- Record the tested Herdr version and protocol/schema version.
- Save private commands and sanitized diagnostic output outside this public repo when necessary.
- Confirm any fallback design against the current source/row contract and `tests/test-state-contract.sh`.
- Run `./scripts/check` for any public repo change.
