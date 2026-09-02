# GPU Physarum Simulation

This effect runs the agent simulation, atomic deposits, 3x3 trail diffusion, and decay entirely on the GPU. A regular URP unlit shader displays the resulting trail and/or the current particle density on a quad.

## Quick start

1. Choose **GameObject > Graphics Playground > Physarum Simulation**.
2. Point the quad at the camera (the generated quad lies in local XY).
3. Enter Play Mode.
4. Choose a pattern with the **Pattern** slider and tune its exposed values live. Pattern selection applies automatically. The **Spawn Shape** slider restarts the agents with the selected distribution.

The component loads its compute shader and display shader automatically. It can also be added to any object with a `MeshFilter` and `MeshRenderer`; if no mesh is assigned, it generates a unit quad.

## Main controls

- **Resolution / Agent Count:** Visual detail and GPU cost. 1024 square and 262,144 agents are a balanced desktop default.
- **Iterations Per Frame:** Simulation speed and cost. This is deterministic per rendered frame, which is convenient for offline video capture.
- **Signal Curves:** Each value follows `constant + response * sensedTrail^exponent`. Distances are pixels and angles are degrees.
- **Response Probe Offsets:** Change where the trail-dependent signal is read before evaluating the four curves.
- **Diffusion / Decay / Deposit:** Control trail spread, memory, and reinforcement.
- **Display Mode and palette:** Do not affect simulation state and can be tuned without a reset.

Changing the resolution or agent count rebuilds GPU resources. Changing the spawn shape automatically resets the agents; other initial-distribution edits can be committed with **Reset Simulation**. Other simulation parameters update live.

The implementation is based on the algorithmic description in Etienne Jacob's [“Algorithms for making interesting organic simulations”](https://bleuje.com/physarum-explanation/), which in turn discusses Jeff Jones' Physarum model and Sage Jenson's trail-dependent extension. This implementation and its included presets were written specifically for this Unity project; no preset table or source code was copied from 36 Points.
