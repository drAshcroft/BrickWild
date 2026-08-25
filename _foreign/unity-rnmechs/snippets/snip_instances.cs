var sb = new System.Text.StringBuilder();
var sims = UnityEngine.Object.FindObjectsByType<RNMechs.Simulation.SimulationController>(UnityEngine.FindObjectsSortMode.None);
sb.Append("SimulationControllers=" + sims.Length);
foreach (var s in sims) sb.Append(" [" + s.name + " active=" + s.gameObject.activeInHierarchy + " enabled=" + s.enabled + " state=" + s.State + "]");
sb.AppendLine();
var machines = UnityEngine.Object.FindObjectsByType<RNMechs.Simulation.SimulatedMachine>(UnityEngine.FindObjectsSortMode.IncludeInactive);
sb.Append("SimulatedMachines=" + machines.Length);
foreach (var mm in machines) {
    var b = mm.ChassisBody;
    sb.Append(" [" + mm.name + " pos=" + (b != null ? b.position.ToString("F1") : "null") + " active=" + mm.gameObject.activeInHierarchy + "]");
}
sb.AppendLine();
var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
var c = sim.LiveMachine.ChassisBody;
var p0 = c.position;
sb.Append("LiveMachine=" + sim.LiveMachine.name + " posNow=" + p0.ToString("F2"));
// sample drift over ~1s of physics
for (int i = 0; i < 60; i++) { }
return sb.ToString();
