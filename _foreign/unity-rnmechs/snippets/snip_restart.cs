var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
sim.StopSimulation();
sim.StartSimulation();
Application.runInBackground = true;
return "restarted; LiveMachine=" + (sim.LiveMachine != null ? sim.LiveMachine.name : "NULL");
