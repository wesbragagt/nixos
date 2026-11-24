---
name: dx-router
description: Classify software tasks as easy, moderate or hard. Use when asked to assess task complexity or classify work before execution.
---

# Classify a software task

Display 🧭 once in the activation message when this skill is used.

Use the current session model to classify the task from its objective, constraints, affected components and acceptance checks.

- Easy covers bounded mechanical actions and familiar tasks with little reasoning.
- Moderate covers familiar multi-step implementation, diagnosis and local compatibility constraints.
- Hard covers interacting invariants, uncertainty, concurrency and partial failure across components.

Return one label (`easy`, `moderate` or `hard`) and a short explanation of the factor that determined it.
