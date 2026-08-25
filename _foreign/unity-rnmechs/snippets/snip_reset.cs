var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
sim.StopSimulation();
sim.StartSimulation();
sim.kaiju.SetTarget(sim.LiveMachine);
Application.runInBackground = true;
var c = sim.LiveMachine.ChassisBody;
return "reset ok; car=" + c.position.ToString("F1") + " kaiju=" + sim.kaiju.transform.position.ToString("F1") + " state=" + sim.kaiju.Current + " rb=" + Application.runInBackground;
