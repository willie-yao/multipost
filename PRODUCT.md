# Product

<!-- impeccable:product-schema 1 -->

Status: historical product discovery/design record from 2026-11-16. The user subsequently authorized local Android implementation. Current behavior and limits are in [README](README.md) and [release evidence](docs/release/evidence.md); native/live acceptance and public release remain incomplete.

## Platform

android

Phone first. The primary user owns an Android phone. Other platforms are an interest for later; no additional launch platform is committed.

## Stack

Flutter was selected for the local Android implementation under `app/`. Other platforms remain later interests. There is no required app backend; live integrations remain gated.

## Users

Individuals who personally compose and publish their own posts. The app is human operated, not an agency dashboard or an AI-agent tool.

## Product Purpose

Compose a shared post, attach photos or video, choose X/Twitter, Bluesky, and/or Instagram, and optionally customize each destination. Make everyday posting simple, clear, pleasant, and recoverable.

## Positioning

A lightweight, open-source personal posting app. Honest destination capabilities and recoverable partial results are central to its usefulness. Do not assume a Postiz fork.

## Operating Context

Install the app and connect accounts. The user prefers on-device drafts and no server to manage. Official account connection and publishing without an operated service remain feasibility questions, not established capabilities.

## Capabilities and Constraints

- Shared composer, media, destination selection, per-platform edits, and previews.
- Drafts and recovery so work is not lost.
- Individual destination results, partial success, and retrying failed destinations without reposting successful ones.
- Instagram personal accounts must remain supported through an assisted flow: prepare media, copy caption, hand off where supported, and provide save-media/copy-caption fallback.
- The user finishes publication inside Instagram. Distinguish ready to share, handed off, and user marked as posted. Opening Instagram is not proof of publication.
- Instagram MVP preparation covers feed photos and carousels. Instagram video, Reels, and Stories are deferred. Shared-composer video for X and Bluesky remains in scope subject to feasibility.
- No unofficial APIs, password collection, browser automation, required AI services, or agent-driven workflows.
- Account connection must explain capabilities honestly, including unsupported or unavailable actions.
- Design empty, loading, validation, disconnected-account, and error states.

## Brand Commitments

Distinctive but restrained visual identity. Prioritize task completion, accessibility, and legibility. Caption is the selected development design/name; final public product identity remains unselected.

## Selected Experience

The user selected **Choose -> write -> review** from the design comparison on 2026-11-16 (option `guided`). Choose destinations first, then write shared content with optional destination edits, then explicitly review publication and preparation actions. The flow is retained. The initial warm-plum and clear-blue visual alternatives were subsequently rejected as too generic; visual identity is open again, with a request for more distinctive mockups. Familiar Android controls, readability, accessibility, and truthful status language remain binding. On 2026-11-16 the user selected the dark **Caption, with more flair** concept (docs/design/options-dark/, v2) for further design refinement. This records the design selection at that time. Later authorization covers local implementation; it does not complete native/live acceptance or authorize public release.

## Evidence on Hand

The original discovery had an empty workspace and illustrative boards. Local Android source, host tests and scoped synthetic API 29 native evidence now exist; see [Android acceptance](docs/testing/android-acceptance.md). Design boards remain illustrative, and neither synthetic screenshots nor fake provider outcomes establish production acceptance.

## Product Principles

1. Keep the everyday compose-and-share task central.
2. Tell the truth about publication and the source of each status.
3. Preserve work and make the next recovery action clear.
4. Keep installation and maintenance approachable.
5. Add scope only when its value is discussed.

## Accessibility & Inclusion

Accessible, legible controls and feedback are explicit priorities. Concrete accessibility criteria will be proposed in the design brief.

## Explicit Non-goals

The original discovery was design-only; local implementation was later authorized. No required backend or live provider activation is authorized by this record. No analytics, team management, scheduling, required AI, agent workflows, automatic Instagram publication, or unrequested major features.

## Open Decisions

Exact official authentication and posting capabilities; app registration, provider access, cost, and any service requirement; supported OS versions; eventual additional platforms; backup/export behavior; final public name/application ID, MIT copyright holder (MIT selected 2026-11-17); platform media constraints. These must not be presented as proven or settled.
