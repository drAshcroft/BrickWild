var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
var m = sim.LiveMachine;
var c = m.ChassisBody;
// reseat: spawn pose facing +Z, kill all motion on every part body
c.position = new Vector3(0f, 1.5f, 5f);
c.rotation = Quaternion.Euler(0f, 0f, 0f);
c.linearVelocity = Vector3.zero;
c.angularVelocity = Vector3.zero;
foreach (var p in m.Parts) {
    if (p.Body != null && p.Body != c) {
        p.Body.position = c.position + c.rotation * (p.Body.position - c.transform.position);
        p.Body.rotation = c.rotation * Quaternion.Inverse(c.transform.rotation) * p.Body.rotation;
        p.Body.linearVelocity = Vector3.zero;
        p.Body.angularVelocity = Vector3.zero;
    }
}
return "reseated car=" + c.position.ToString("F1") + " rot=" + c.rotation.eulerAngles.ToString("F0") + " fwd=" + c.transform.forward.ToString("F2");
