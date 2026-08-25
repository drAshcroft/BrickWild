var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
var m = sim.LiveMachine;
var c = m.ChassisBody;
var sb = new System.Text.StringBuilder();
sb.AppendLine("mass=" + c.mass + " inertia=" + c.inertiaTensor.ToString("F0"));
sb.AppendLine("vel=" + c.linearVelocity.ToString("F2") + " angVel=" + c.angularVelocity.ToString("F2"));
// wheel contact check: how many wheels touch ground
var grounded = 0;
foreach (var p in m.Parts) {
    if (!p.Entry.Definition.isLocomotion) continue;
    if (Physics.Raycast(p.Body.position, Vector3.down, 0.45f)) grounded++;
}
sb.AppendLine("wheels grounded=" + grounded + "/4");
// friction of wheel material
var wheel = m.Parts[1];
var sc = wheel.Go.GetComponent<SphereCollider>();
sb.AppendLine("wheel mat=" + (sc.sharedMaterial != null ? sc.sharedMaterial.name : "NULL (default 0.6)") +
    " dynamicFriction=" + (sc.sharedMaterial != null ? sc.sharedMaterial.dynamicFriction.ToString() : "0.6?"));
// ground material
if (Physics.Raycast(c.position + Vector3.up, Vector3.down, out var hit, 5f)) {
    var gcol = hit.collider;
    sb.AppendLine("ground mat=" + (gcol.sharedMaterial != null ? gcol.sharedMaterial.name : "NULL") +
        " combine=" + (gcol.sharedMaterial != null ? gcol.sharedMaterial.frictionCombine.ToString() : "-"));
}
return sb.ToString();
