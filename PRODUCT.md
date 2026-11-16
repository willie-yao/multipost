# Product

<!-- impeccable:product-schema 1 -->

Status: product discovery for a design-only review, 2026-11-16. No implementation authorized.

## Platform

android

Phone first. The primary user owns an Android phone. Other platforms are an interest for later; no additional launch platform is committed.

## Stack

Flutter is the user's preferred candidate for reaching multiple platforms, provisionally. No framework project, backend, prototype, or live integration is to be created in this session.

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

Distinctive but restrained visual identity. Prioritize task completion, accessibility, and legibility. No product name or existing brand assets have been selected.

## Selected Experience

The user selected **Choose -> write -> review** from the design comparison on 2026-11-16 (option `guided`). Choose destinations first, then write shared content with optional destination edits, then explicitly review publication and preparation actions. The flow is retained. The initial warm-plum and clear-blue visual alternatives were subsequently rejected as too generic; visual identity is open again, with a request for more distinctive mockups. Familiar Android controls, readability, accessibility, and truthful status language remain binding. On 2026-11-16 the user selected the dark **Caption, with more flair** concept (docs/design/options-dark/, v2) for further design refinement. It is not yet a final visual system and does not authorize implementation.

## Evidence on Hand

An empty project workspace and the user's discovery answers. No app implementation, integration test, platform capability validation, or production screenshots exist. Screen content produced in this session must be identified as illustrative.

## Product Principles

1. Keep the everyday compose-and-share task central.
2. Tell the truth about publication and the source of each status.
3. Preserve work and make the next recovery action clear.
4. Keep installation and maintenance approachable.
5. Add scope only when its value is discussed.

## Accessibility & Inclusion

Accessible, legible controls and feedback are explicit priorities. Concrete accessibility criteria will be proposed in the design brief.

## Explicit Non-goals

No implementation in this session. No backend, live integration, or prototype. No analytics, team management, scheduling, required AI, agent workflows, automatic Instagram publication, or unrequested major features.

## Open Decisions

Exact official authentication and posting capabilities; app registration, provider access, cost, and any service requirement; supported OS versions; eventual additional platforms; backup/export behavior; final name and license; platform media constraints. These must not be presented as proven or settled.
