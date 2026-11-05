---
name: devcontainer-feature-best-practices
description: Retrieve and apply current best practices for writing a devcontainer feature. Make sure to use this skill whenever the user asks about authoring, improving, reviewing, or structuring a devcontainer Feature, devcontainer-feature.json, install.sh, feature options, dependencies, or publishing features — even if they don't use the exact phrase "best practices."
---

# Devcontainer Feature Best Practices

This skill fetches current best practices for authoring devcontainer Features from the official containers.dev documentation and applies them to the user's situation.

## Why fetch live docs

The Features spec evolves (new metadata fields, lifecycle hooks, distribution changes). Bundled copies go stale, so always retrieve the current docs rather than relying on memory.

## Workflow

1. **Fetch the primary spec page first:**
   `https://containers.dev/implementors/features/`
   This covers folder structure, all `devcontainer-feature.json` properties, lifecycle hooks, options handling, user environment variables (`_REMOTE_USER`, `_CONTAINER_USER`, `_REMOTE_USER_HOME`, `_CONTAINER_USER_HOME`), execution of `install.sh`, installation ordering (`dependsOn` vs `installsAfter` vs `overrideFeatureInstallOrder`), option resolution, and renaming features.

2. **Fetch related pages based on the user's question:**
   - Folder structure / getting started / publishing: `https://containers.dev/implementors/features-distribution/`
   - Authoring a new feature repo: `https://github.com/devcontainers/feature-starter` (via its README, e.g. `https://raw.githubusercontent.com/devcontainers/feature-starter/main/README.md`)
   - CI, testing, versioning, release automation: `https://containers.dev/implementors/contributing/`
   - devcontainer.json reference (lifecycle command formatting, variables): `https://containers.dev/implementors/json_reference/`
   - Templates (if the user might actually want a template): `https://containers.dev/implementors/templates/`

   Follow in-page links when the user's question touches a topic the index page only summarizes. Avoid fetching pages you don't need — start with the one whose topic matches the question.

3. **Extract best practices relevant to the user's question.** Common themes:
   - Feature layout: `devcontainer-feature.json` + executable `install.sh` + supporting files
   - `id` must match the directory name; semver `version`; accurate `description`, `documentationURL`, `licenseURL`, `keywords`
   - Options: typed (`string`/`boolean`), sensible `default`s, `enum`/`proposals`; remember they arrive as uppercased env vars (e.g. `version` → `VERSION`)
   - `install.sh` runs as root during image build; use `_REMOTE_USER`/`_CONTAINER_USER` (+ `_HOME` variants) instead of assuming a user; make it distro-portable (bash on Debian/Fedora, sh on Alpine); detect architecture (`uname -m`) for x86_64/arm64
   - Keep layers cache-friendly; clean up apt caches and temp files
   - Use `dependsOn` for hard requirements, `installsAfter` for soft ordering; never create cycles
   - Lifecycle hooks (`postCreateCommand`, etc.) for anything that must run after container creation rather than at image build
   - `containerEnv`, `mounts`, `privileged`, `capAdd`, `customizations` only when truly needed
   - Adopt an existing Feature (e.g. `ghcr.io/devcontainers/features/common-utils`) via `installsAfter` where relevant instead of re-implementing

4. **Answer with specifics.** Tie recommendations back to the user's concrete file (`devcontainer-feature.json` snippets, corrected `install.sh` lines, etc.) and cite the source URL(s) for each non-obvious claim. Quote local file paths and option names exactly.

## Output format

Structure the answer as:

1. **Short answer** — one or two sentences.
2. **Relevant practices** — bullet points grouped by topic, each with a source link.
3. **Applied to your feature** — concrete diff/snippet suggestions referencing the user's files, if they shared any.
4. **Sources** — list of pages fetched.

If the user only asked a narrow question (e.g. "what fields does devcontainer-feature.json support?"), keep the response focused on that and skip the generic checklist.
