# External 3D assets

The game is fully runnable without external assets. Enemies fall back to a procedural cyberpunk capsule model.

## Tripo enemy model

1. Generate a humanoid cyberpunk enemy in Tripo.
2. Export as GLB/GLTF with textures.
3. Place it at `assets/models/enemy.glb`.
4. Godot will automatically use the model on next launch.

Recommended prompt direction: cyberpunk security trooper, readable silhouette, emissive visor, neutral A-pose/T-pose, game-ready topology.

## Mixamo animations

A robust production workflow is:

1. Upload the same humanoid mesh to Mixamo and auto-rig it.
2. Download Idle, Running, Shooting/Attack and Death animations.
3. Import them into Godot and retarget them to the enemy skeleton if necessary.
4. Ensure the final `AnimationPlayer` inside `enemy.glb` exposes animation names matching one of the aliases used in `scripts/enemy.gd`:
   - Idle / idle
   - Run / run / Walking / walking
   - Attack / attack / Shooting / shooting
   - Death / death / Dying / dying

The runtime intentionally does not require these assets so the repository remains self-contained and playable.
