var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
var m = sim.LiveMachine;
var c = m.ChassisBody;
var sb = new System.Text.StringBuilder();
// what are the wheel colliders' actual friction values at runtime?
foreach (var p in m.Parts) {
    if (!p.Entry.Definition.isLocomotion) continue;
    var col = p.Go.GetComponent<Collider>();
    var mat = col.material;   // runtime instance
    sb.AppendLine("wheel " + p.Entry.Definition.partId +
        " dynFric=" + mat.dynamicFriction.ToString("F2") +
        " staticFric=" + mat.staticFriction.ToString("F2") +
        " combine=" + mat.frictionCombine);
}
// ground
if (Physics.Raycast(c.position + Vector3.up, Vector3.down, out var hit, 5f)) {
    var gmat = hit.collider.material;
    sb.AppendLine("ground dynFric=" + gmat.dynamicFriction.ToString("F2") +
        " combine=" + gmat.frictionCombine);
}
return sb.ToString();
