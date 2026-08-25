var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
var m = sim.LiveMachine;
var c = m.ChassisBody;
// Friction is normal (0.6 avg). So why is yaw dead? Test: torque with WHEEL JOINTS
// angular axes freed — the locked angularX/Y/ZMotion on wheel joints transmit the
// chassis twist into the wheels; wheels then resist via ground friction.
// Quick empirical: apply yaw torque to CHASSIS *AND* every wheel simultaneously:
foreach (var p in m.Parts) p.Body.AddTorque(Vector3.up * 600f);
var start = Time.frameCount;
UnityEditor.EditorApplication.CallbackFunction pump = null;
pump = () => {
    UnityEditor.EditorApplication.QueuePlayerLoopUpdate();
    if (Time.frameCount >= start + 90) UnityEditor.EditorApplication.update -= pump;
};
UnityEditor.EditorApplication.update += pump;
return "600 N·m on ALL 5 bodies, 90 frames";
