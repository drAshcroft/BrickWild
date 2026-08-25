var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
var m = sim.LiveMachine;
var c = m.ChassisBody;
var sb = new System.Text.StringBuilder();
sb.AppendLine("state=" + sim.State + " carPos=" + c.position.ToString("F1") +
    " speed=" + c.linearVelocity.magnitude.ToString("F1"));
var k = sim.kaiju;
sb.AppendLine("kaiju=" + k.Current + " pos=" + k.transform.position.ToString("F1") +
    " dist=" + Vector3.Distance(c.position, k.transform.position).ToString("F0"));
var village = UnityEngine.Object.FindFirstObjectByType<RNMechs.Level.VillageStructureBuilder>(UnityEngine.FindObjectsInactive.Include);
var blocks = 0; var kinematic = 0;
foreach (var b in village.GetComponentsInChildren<RNMechs.Simulation.DestructibleBlock>()) {
    blocks++;
    if (b.Body.isKinematic) kinematic++;
}
sb.AppendLine("village blocks=" + blocks + " kinematic=" + kinematic);
return sb.ToString();
