var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
var m = sim.LiveMachine;
var c = m.ChassisBody;
var sb = new System.Text.StringBuilder();
sb.AppendLine("pos=" + c.position.ToString("F1") + " vel=" + c.linearVelocity.ToString("F2"));
// is the keyboard simulation actually registering? check wKey.isPressed while course pumps:
var course = UnityEngine.Object.FindFirstObjectByType<RNMechs.AiPlaytest.DriveCourse>(UnityEngine.FindObjectsInactive.Include);
sb.AppendLine("phase=" + course.phase);
// manually pump W via the same path and read isPressed next frame:
RNMechs.Simulation.SimDriveController.AgentInput = null;
var kb = UnityEngine.InputSystem.Keyboard.current;
sb.AppendLine("wKey.isPressed NOW=" + kb.wKey.isPressed + " (course done so expect False)");
// The real question: why did speed drop to ~0.1 mid-course? The car stopped moving.
// Check if something blocks: distance from spawn
sb.AppendLine("dist from spawn=" + Vector3.Distance(c.position, new Vector3(0f, 1.5f, 5f)).ToString("F1"));
return sb.ToString();
