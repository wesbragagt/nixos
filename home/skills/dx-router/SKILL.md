---
name: dx-router
description: Classify software tasks as easy, moderate or hard using local Decision-0.8B. Use when asked to assess task complexity or classify work before execution.
---

# Classify a software task

Display 🧭 once in the activation message when this skill is used.

Use one local inference pass to classify the task as easy, moderate or hard.

- Easy covers bounded mechanical actions and familiar tasks with little reasoning.
- Moderate covers familiar multi-step implementation, diagnosis and local compatibility constraints.
- Hard covers interacting invariants, uncertainty, concurrency and partial failure across components.

## Local API

In this NixOS repo, set `dx-router: true` under the existing features section of `/etc/nixos/features.yaml`, then run `rebuild`. The feature supplies pinned Decision-0.8B Q8_0 weights, a Vulkan-enabled llama.cpp user service and the API at `http://127.0.0.1:18085`.

Check `systemctl --user status dx-router` and `curl --fail http://127.0.0.1:18085/health`. Check service startup output for GPU offload.

On other machines, supply a compatible llama.cpp server running Decision-0.8B Q8_0 with a 2048-token context. The client requires Python 3 standard library and HTTP loopback access. Use `--base-url` for another loopback endpoint.

## Classification

Resolve the script relative to this skill directory and pass the task on stdin.

```sh
printf '%s' 'Implement cursor pagination while preserving response fields.' |
  python3 /path/to/dx-router/scripts/route.py
```

Report the returned complexity. Include latency or scores when requested. Scores are relative option weights with unmeasured calibration. Report invalid input, context rejection and unavailable runtime as classification failures. The full formatted prompt must leave one answer token within the 2048-token context.

The local software evaluation matched 11 of 15 synthetic expected tiers. Treat classification as a recommendation. Use a single pass without a score threshold or voting policy.
