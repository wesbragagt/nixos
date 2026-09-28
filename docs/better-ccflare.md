# Machine feature toggles

Machine-local feature flags live at `/etc/nixos/features.yaml`.
The file is not stored in this repository. A repository copy such as `config/features.yaml` is gitignored.

Missing files disable optional features by default.
This allows server bootstrapping without desktop or user-tool modules.

Example:

```yaml
features:
  claude-code: true
  omp: true
  mnemosyne: true
```

Feature names are parsed from lines with this form:

```yaml
  feature-name: true
```

Set a feature to `false`, or remove the line, to disable it.

## Available features

- `claude-code` enables the Claude Code Home Manager module.
- `omp` enables the Open Model Platform (OMP) Home Manager module.
- `gaming` installs Lutris on desktop hosts (skipped on headless hosts).
- `mnemosyne` installs the Mnemosyne memory CLI and its default shared-bank environment.

The default for all listed features is disabled.
Host-specific profile settings still control hardware, desktop, and secret behavior.

Apply changes with:

```bash
rebuild build
rebuild
```

## better-ccflare

better-ccflare runs on a separate machine, `hostinger-kvm2`, not in this repository.
It is a docker-compose deployment at `/home/wesbragagt/dev/stack/packages/better-ccflare/docker-compose.yml`,
published over Tailscale as:

```text
Dashboard: https://ccflare.dory-pentatonic.ts.net/
Health:    https://ccflare.dory-pentatonic.ts.net/health
API base:  https://ccflare.dory-pentatonic.ts.net/v1
```

There is no local better-ccflare instance on any NixOS host managed by this repo.

### Updating better-ccflare

```bash
ssh hostinger-kvm2
cd /home/wesbragagt/dev/stack/packages/better-ccflare
sudo docker compose pull better-ccflare
sudo docker compose up -d better-ccflare
```

The image tag is `latest`; this pulls and recreates only the `better-ccflare` service, not the `tailscale` sidecar.

### Managing accounts

```bash
ssh hostinger-kvm2
sudo docker exec better-ccflare better-ccflare --list
sudo docker exec better-ccflare better-ccflare --set-priority <name> <priority>
sudo docker exec better-ccflare better-ccflare --pause <name>
sudo docker exec better-ccflare better-ccflare --resume <name>
sudo docker exec better-ccflare better-ccflare --reauthenticate <name>
```

ccflare selects the highest-priority active account that supports the request.
Auto-fallback and provider model mappings are dashboard-only settings, at
`https://ccflare.dory-pentatonic.ts.net/accounts` — there is no CLI flag for them.

Account credentials live in the `ccflare-data` docker volume on `hostinger-kvm2`.
Do not add provider tokens or OAuth data to this repository.

## Shared ccflare pointer

Claude Code and OMP both route through the same ccflare endpoint.
The single source of truth is `home/ccflare/config.yml`:

```yaml
baseUrl: https://ccflare.dory-pentatonic.ts.net
apiKey: ccflare-local
models:
  - claude-opus-4-8
  - claude-sonnet-5
  - claude-sonnet-5-5
  - claude-fable-5-1
  - claude-haiku-4-5
  - gpt-5.6-luna
  - gpt-5.6-terra
  - gpt-5.6-sol
  - gpt-6-astra
```

Edit this file to change the base URL, API key, or model list.
The trailing `/v1` is not included in `baseUrl`.
Apply the change with `rebuild build` followed by `rebuild`.

The `home/ccflare` module reads this file at evaluation time and exposes
`config.wes.ccflare.baseUrl`, `apiKey`, and `models`.

- `home/omp/default.nix` generates `~/.omp/agent/models.yml` from these
  values, in the provider format OMP expects.

OMP only shows model IDs listed in `home/ccflare/config.yml`.
The active Codex OAuth account cannot provide a model catalog.
Test each new model before adding it.

### Model metadata for models OMP does not know

OMP builds model metadata from its bundled catalog. When a model ID is
missing there, OMP falls back to `contextWindow 128000`,
`maxTokens 16384`, `reasoning false` and zero cost. That breaks compaction
and cost reporting.

Add the real values to `modelMetadata` in `home/omp/default.nix`. The
generator writes them into each `models.yml` entry. `gpt-6-astra` has such
an entry.

Get the values from the models.dev catalogue, the same source OMP builds
from:

```bash
curl -s https://models.dev/api.json | jq '.openai.models["gpt-6-astra"]'
```

Check the result without a rebuild by pointing OMP at a copy:

```bash
PI_CODING_AGENT_DIR=/tmp/omp-test/agent omp models ccflare --json
```

A model requiring a newer Claude Code client version than OMP sends will fail
with `claude_code_version_too_old`. OMP hardcodes the client-version string it
impersonates for OAuth Anthropic requests; ccflare only reflects whatever
version the calling client sends. Fix by upgrading `wes.omp.version` in
`home/omp/default.nix`, not by touching ccflare.

Check the configured OMP models:

```bash
omp models ccflare --json
```

Test the default OMP route:

```bash
omp --print --no-session "Reply with exactly: ccflare verified"
```

The OMP `usage` status segment does not report ccflare usage.
It reports local OMP provider credentials.
Do not enable it when ccflare is the active route.

### Codex (GPT) model access and force_account_model

The `gpt-5.6-*` and `gpt-6-astra` models route through the Codex OAuth
accounts (`codex-work`, `codex-personal`), not the Anthropic accounts.
Keep at least one `codex` mode account active, or every GPT request fails.

By default, ccflare's `session` load-balancing strategy picks an account by
session affinity and priority, not by which account can actually serve the
requested model. A direct model request such as `gpt-5.6-luna` can land on
the pinned Anthropic account first, which returns
`{"type":"not_found_error","message":"model: gpt-5.6-luna"}` and does not
fail over, because a 404 model error is not a retryable failure class.

ccflare's dashboard-only `force_account_model` setting fixes this: with it
on, account selection only considers accounts whose own model listing (or
provider namespace) actually supports the literal requested model name. This
setting is enabled on this instance (`POST /api/config/force-account-model`,
`{"enabled": true}`).

Trade-off: this also disables the default Claude-family-to-Codex silent
fallback. Before this was enabled, a `claude-sonnet-5` request could quietly
get served by `gpt-5.6-sol` if the Anthropic account was unavailable. With
`force_account_model` on, that request now fails outright instead of
silently switching model/vendor. This is intentional: Claude requests must
not silently route to Codex.

`gpt-5.4` (not `-mini`) is not usable on this ChatGPT plan and returns
`"The 'gpt-5.4' model is not supported when using Codex with a ChatGPT
account."` This is an OpenAI account entitlement limit, not a ccflare or
repo config issue.

`gpt-5.4-mini` is not in the `codex-work` model listing, so no active
account serves it. It is removed from `home/ccflare/config.yml`.

### Do not serve GPT models from an openai-compatible account

An `openai-compatible` (console mode) account points at
`https://api.openai.com/v1` and translates the Anthropic request to OpenAI
chat completions. That adapter keeps `max_tokens`, which the GPT-5 family
rejects:

```text
400 Unsupported parameter: 'max_tokens' is not supported with this model.
Use 'max_completion_tokens' instead.
```

ccflare 3.5.79 still has this behaviour, so an image upgrade does not fix it.
The `gpt-5.6-*` names are also ccflare aliases, not real OpenAI API model
IDs. Confirm the routed account with:

```bash
ssh hostinger-kvm2 'sudo docker logs --since 5m better-ccflare 2>&1 | grep -iE "force account model|Attempting request with account"'
```

Then pause the `openai-compatible` account and resume a `codex` mode
account.

