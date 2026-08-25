var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
var c = sim.LiveMachine.ChassisBody;
RNMechs.Simulation.SimDriveController.AgentInput = null;
var yaw = c.rotation.eulerAngles.y;
return "yaw after 1.5s of D = " + yaw.ToString("F0") + "° (started 0°) angVel=" + c.angularVelocity.ToString("F2");
