var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
var m = sim.LiveMachine;
var c = m.ChassisBody;
// hold D for 90 frames, then report yaw delta
RNMechs.Simulation.SimDriveController.AgentInput = (0f, 1f, false, false);
var start = Time.frameCount;
UnityEditor.EditorApplication.CallbackFunction pump = null;
pump = () => {
    UnityEditor.EditorApplication.QueuePlayerLoopUpdate();
    if (Time.frameCount >= start + 90) UnityEditor.EditorApplication.update -= pump;
};
UnityEditor.EditorApplication.update += pump;
return "D held for 90 frames";
