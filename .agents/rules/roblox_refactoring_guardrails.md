# Roblox Luau Refactoring & Zero-Regression Guardrails

These guidelines ensure zero regressions and maintain architectural integrity when refactoring Roblox Luau projects:

1. **Dual-Sync Global State (`_G`)**:
   - When migrating legacy code relying on `_G` to modular state scripts (e.g., `ClientSettingsState`, `LeaderboardRegistry`), maintain bidirectional or outward synchronization to `_G`.
   - Never wipe or deprecate `_G` variables abruptly, as place-file scripts embedded in Roblox Studio Workspace or other uncommitted scripts may depend on them.

2. **Physics & State Separation (SRP)**:
   - Separate humanoid physics manipulations (`Weld`, `Motor6D`, `Massless`, `CanCollide`, `HumanoidStateType`, `SetNetworkOwner`) into a dedicated `Physics` module.
   - Keep session lifetimes, in-memory tables, and timeout checks in a dedicated `State` module, leaving the server script as a lean orchestrator/controller.

3. **Staggered Avatar Spawning & Cache Checking**:
   - Always stagger asynchronous model fetches (`Players:CreateHumanoidModelFromUserId`) with task.wait intervals (~1-1.5s) to avoid freezing Studio network/rendering pipelines.
   - Maintain a cache of active `userId`s to update existing BillboardGui elements in-place on data refreshes rather than recreating full humanoid models.

4. **Centralized Remote & DataStore Registries**:
   - Never hardcode RemoteEvent/RemoteFunction names, folder paths, or DataStore keys in multiple scripts.
   - Maintain single-source-of-truth registries in `ReplicatedStorage.Config.RemoteNames` and `ServerScriptService.Config.ServerConfig`.

5. **Animation Sequence Timing & Guaranteed Lighting Cleanup**:
   - Ensure safety timeouts (`task.delay`) always comfortably exceed the maximum sequence duration (including all `task.wait` and tween times) to prevent deleting instances while the thread is still running.
   - For temporary visual effects that modify `Lighting` (`ColorCorrectionEffect`, `BloomEffect`), never rely solely on linear script completion. Always wrap cleanup in guaranteed fail-safe logic (`pcall`) and clean up any pre-existing lingering effect instances in `Lighting` before creating new ones to prevent visual stacking.
