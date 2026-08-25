var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
var c = sim.LiveMachine.ChassisBody;
var m = sim.LiveMachine;
float mass = 0f;
foreach (var p in m.Parts) if (p.Body != null) mass += p.Body.mass;
return "gravity=" + Physics.gravity.ToString("F2") + " totalMass=" + mass.ToString("F1")
  + " carY=" + c.position.y.ToString("F0") + " speed=" + c.linearVelocity.magnitude.ToString("F0");
