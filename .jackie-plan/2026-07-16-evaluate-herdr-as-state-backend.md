---
id: 2026-07-16-evaluate-herdr-as-state-backend
title: Evaluate Herdr as workflow replacement
state: inbox
createdAt: 2026-07-16T05:27:59.887Z
updatedAt: 2026-07-16T05:36:46.844Z
sourcePlan: 2026-07-14-design-shareable-remote-adapter-package
---

# Evaluate Herdr as workflow replacement

## Plan

## Objective

Evaluate Herdr first as a wholesale replacement for the current tmux session, agent-status, and navigation workflow. Only evaluate Herdr as a state backend or `tmux-agent-bar` source adapter if the TUI is not a complete fit or the real SSH-like topology prevents wholesale adoption.

Run the decisive topology tests on the machine where agents actually work across remote boundaries. The output is an adoption decision and migration sketch, not an implementation.

## Current recommendation

Treat wholesale adoption as the leading hypothesis, not the long shot.

Herdr already covers most of the user-facing surface that `tmux-agent-bar` and the surrounding tmux setup are trying to assemble: persistent terminals, project-level navigation, tabs and splits, agent state, attention ordering, searchable switching, remote attach, notifications, and a customizable sidebar. A short hands-on TUI pilot is now the cheapest and most decisive next step.

Do not build an adapter first. If Herdr can own the relevant panes and its TUI feels good, keeping tmux plus a Herdr-to-row bridge would preserve complexity instead of removing it.

## Preliminary TUI assessment

Herdr's hierarchy maps reasonably onto the current workflow:

- one Herdr server session is the persistent runtime;
- a Herdr workspace is the likely replacement for a tmux session or project context;
- tabs separate views within a workspace;
- panes are real terminals and splits;
- the sidebar shows both workspaces and agents, with rolled-up state and attention.

The keyboard surface is credible for a keyboard-first workflow:

- `prefix+w` opens a persistent navigate mode for moving through workspaces and panes;
- `prefix+g` opens a searchable workspace/tab/pane tree with agent-state filters;
- `prefix+1..9` switches tabs;
- workspace 1-9, agent 1-9, previous/next workspace, and previous/next agent actions exist and can be bound explicitly;
- `prefix+h/j/k/l` moves between panes, with split, zoom, swap, resize, close, and copy-mode bindings following familiar tmux conventions;
- every binding and the prefix are configurable, and direct `ctrl+alt` chords can coexist with prefix bindings;
- `prefix+q` detaches while the server and pane processes keep running.

The UI is not an all-or-nothing space cost. The expanded sidebar defaults to a compact workspace/branch and agent/state layout, can be collapsed with `prefix+b`, and can be configured so collapsed means fully hidden. Agent ordering can be grouped by workspace or sorted by attention priority. Row tokens, labels, colors, width bounds, and per-agent layouts are configurable.

Other potentially useful replacement features include mouse selection and split resizing, searchable copy mode, session-modal popup terminals and custom commands, built-in Git worktree flows, notifications and sounds, mobile/narrow-terminal layouts, and a socket API for later custom UI work.

An isolated local smoke test of Herdr `0.7.4` confirmed that the desktop layout, searchable navigator, and persistent navigate overlay are coherent and responsive under a nested temporary tmux session. That is enough to justify a real pilot, but not enough to validate terminal fidelity, Neovim behavior, copy/paste, long-running stability, or daily navigation preferences.

## Architectural constraints

The largest risk is no longer the TUI; it is the boundary of one Herdr server.

- Workspaces inside one Herdr server are easy to navigate together.
- Herdr named sessions are separate server namespaces, not one combined switcher. Prefer one session with many workspaces unless isolation is genuinely required.
- `herdr --remote <host>` gives a good thin-client experience for one remote Herdr server.
- Agents launched after plain SSH inside a local Herdr pane are not currently detected; upstream issue `#1170` reports this exact limitation.
- Unified local and multiple-remote Herdr servers are acknowledged upstream but not implemented; issue `#334` describes that desired architecture.
- Herdr owns the PTY/pane in the supported path. Existing tmux sessions and remote wrapper panes are not adopted passively.
- Claude Code and Codex still use screen-manifest detection because their hooks do not cover every lifecycle transition. Background waits can still be classified as done.
- The external snapshot/event API was added in `0.7.2`, so it is promising but young.
- Herdr is AGPL-3.0-or-later or commercially licensed, while this repo is MIT. Reuse documented APIs and concepts, but do not copy implementation code without a deliberate license decision.

If the work machine is one durable control host and all useful work can live inside one Herdr server there, wholesale adoption may fit well. If the current connector opens agents on multiple independent hosts while only streaming terminal views through local panes, Herdr's current remote model may be the blocker.

## Questions to answer

1. Can each current tmux session map naturally to a Herdr workspace inside one server?
2. Can the preferred keyboard flow switch workspace, agent, tab, and pane with no more friction than the current picker and tmux bindings?
3. Is the sidebar useful at normal terminal widths, and is collapsing or hiding it sufficient when maximum pane width matters?
4. Does Herdr faithfully handle Neovim, shell input, copy mode, clipboard behavior, colors, links, mouse modes, resize, scrollback, and long-running output?
5. What owns each live terminal and PTY on the work machine: local tmux, a local connector, a remote multiplexer, or an agent-specific launcher?
6. Can Herdr run where the agents actually live and replace that owner, or would it only wrap an SSH-like connection?
7. Does one Herdr server cover the useful fleet, or does the workflow require aggregation across independent hosts or servers?
8. Is Herdr's state at least as trustworthy as the current setup for active turns, permission prompts, questions, background waits, disconnects, and exits?
9. Are AGPL use and deployment acceptable in the actual environment?

## Evaluation sequence

### 1. Run a time-boxed TUI fit gate

Use a version-pinned, isolated Herdr setup without migrating live work. Spend enough real keyboard time to test the workflow rather than only reading screenshots.

Create several representative workspaces, tabs, and panes. Exercise:

- `prefix+w` navigate mode;
- `prefix+g` search and state filters;
- numbered tab switching and configured numbered workspace/agent switching;
- previous/next agent and workspace bindings;
- pane focus, split, resize, swap, zoom, and close;
- expanded, compact, and hidden sidebar modes;
- attention-priority versus workspace-grouped agent ordering;
- detach and reattach;
- copy mode, clipboard, Neovim, shell history, mouse capture, links, and long output;
- one custom popup command if popups could replace an existing tmux popup.

Record only concrete friction. Reject wholesale adoption early if the terminal or navigation experience is materially worse and cannot be fixed with a small keybinding or sidebar configuration.

### 2. Map the real topology into Herdr

Trace one representative local agent, one SSH-like agent, and one disconnected/reconnected agent from launcher through PTY owner and transport. Determine whether each current tmux session can become a workspace in one Herdr server.

Keep private hostnames, paths, auth details, and proprietary connector names in an untracked work-machine note. Preserve only the generic topology and decision in this public plan.

### 3. Exercise the actual remote shapes

Test these separately:

- plain SSH started inside a local Herdr pane;
- the real SSH-like connector started inside a Herdr pane;
- Herdr running where the work lives and attached with `herdr --remote`;
- more than one remote Herdr server if the real overview spans hosts;
- detach, transport loss, and reconnect while work continues.

Confirm whether `HERDR_AGENT` can make a connector-owned pane classify the live remote UI reliably. Treat that only as a screen-detection hint, not proof of remote lifecycle integration.

### 4. Verify agent state and recovery

In representative Codex and Claude panes, test working, permission/question blocking, idle/done, interrupt, background wait, process exit, detach/reattach, and full Herdr server restart. Distinguish live detach persistence from snapshot restore and native agent-session resume.

Use `agent list --json`, `agent explain --json`, and `api snapshot` to compare visible state with Herdr's underlying model.

### 5. Evaluate the custom-state boundary only if needed

If the TUI is good but remote coverage or one UI detail is missing, build an ephemeral untracked probe that:

- bootstraps from `herdr api snapshot`;
- subscribes to pane/resource events;
- projects Herdr agents into `tmux-agent-bar`'s normalized row shape;
- measures reconnect behavior, event loss, snapshot latency, and state-change latency.

Do not add a daemon or adapter to this repo during evaluation. Treat a required persistent subscriber as an adoption cost.

### 6. Choose one outcome

Prefer outcomes in this order when the evidence supports them:

1. Replace tmux and most or all of `tmux-agent-bar` with one Herdr server and many workspaces.
2. Use Herdr for the topology it can own while retaining a smaller cross-host status surface.
3. Keep tmux and add Herdr only as an optional normalized source.
4. Keep `tmux-agent-bar` and borrow only design ideas.

Choose the smallest overall system, not the smallest immediate migration.

## Ideas worth borrowing if adoption fails

- Bootstrap custom consumers with one snapshot API, then add events for real long-lived clients.
- Separate semantic state from visual metadata and labels.
- Track state authority explicitly so hooks and terminal inference do not compete.
- Preserve stable runtime identity separately from display labels.
- Add row-level `explain` evidence showing authority, matched rule, fallback reason, and freshness.
- Model unseen completion separately from ordinary idle state.
- Keep terminal/output observation owned by the PTY runtime or adapter, never the status renderer.

The existing stable `rows`/`rows-cached` plan remains useful if Herdr is rejected or only partially adopted. Do not implement it merely to preserve a future tmux path before the Herdr evaluation finishes.

## Non-goals

- Do not migrate or terminate active tmux sessions during evaluation.
- Do not build a Herdr adapter before testing wholesale use.
- Do not add Herdr-specific logic to the core renderer during the pilot.
- Do not copy AGPL implementation code into this MIT repository.
- Do not encode private machine topology or work-specific connectors in checked-in files.
- Do not build multi-server aggregation unless the final comparison deliberately selects that as the smallest viable system.

## Adoption criteria

Wholesale adoption is viable only if:

- one Herdr server can represent the useful set of projects and agents, or the loss of a unified multi-server view is acceptable;
- workspace, agent, tab, and pane switching feel at least as fast as the current keyboard workflow;
- the sidebar improves awareness without consuming unacceptable space;
- terminal behavior is trustworthy for Neovim, shells, copy/paste, scrollback, resize, and long-running tools;
- local and remote agents are not silently omitted;
- active work, blocked prompts, background waits, completion, exit, and disconnect are accurate enough to trust;
- detach and reconnect do not require manual repair;
- Herdr removes enough custom navigation, state, and transport code to justify migration and its operational/license constraints.

## Stopping point

Stop after producing:

- a short TUI scorecard;
- a sanitized topology map;
- a state/reconnect evidence table;
- the recommended outcome and rejected alternatives;
- any upstream dependency that blocks adoption;
- a separate migration plan only if wholesale or partial adoption is selected.

Do not migrate live sessions or implement an adapter until that report is reviewed.

## Verification

- Capture the tested Herdr version and protocol/schema version.
- Save sanitized screenshots or command fixtures for navigation, snapshot, state-change, reconnect, and failure cases outside the public repo when they expose private topology.
- Confirm the recommendation against the current `tmux-agent-bar` source/row contract and the active `Harden public adapter platform` plan.
- If public repo files are later changed, run `./scripts/check` and follow the repo's commit/push requirements in that implementation session.
