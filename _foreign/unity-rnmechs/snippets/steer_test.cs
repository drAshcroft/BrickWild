var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
var m = sim.LiveMachine;
var c = m.ChassisBody;
var sb = new System.Text.StringBuilder();
var yaw0 = c.rotation.eulerAngles.y;
// hold D (steer=+1) for ~1.5s of real frames via the AgentInput hook
RNMechs.Simulation.SimDriveController.AgentInput = (0f, 1f, false, false);
var start = Time.frameCount;
UnityEditor.EditorApplication.CallbackFunction pump = null;
pump = () => {
    UnityEditor.EditorApplication.QueuePlayerLoopUpdate();
    if (Time.frameCount >= start + 90) UnityEditor.EditorApplication.update -= pump;
};
UnityEditor.EditorApplication.update += pump;
sb.AppendLine("holding D for 90 frames...");
return sb.ToString();
