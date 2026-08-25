var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
var k = sim.kaiju;
var m = sim.LiveMachine;
return "kaiju=" + k.Current + " pos=" + k.transform.position.ToString("F1") +
    " dist=" + Vector3.Distance(k.transform.position, m.ChassisBody.position).ToString("F0");
