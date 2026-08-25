var sim = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
var m = sim.LiveMachine;
var c = m.ChassisBody;
// reseat straight at spawn, facing +Z, zero all motion
c.position = new Vector3(0f, 1.5f, 5f);
c.rotation = Quaternion.identity;
c.linearVelocity = Vector3.zero;
c.angularVelocity = Vector3.zero;
foreach (var p in m.Parts) {
    if (p.Body != null && p.Body != c) { p.Body.linearVelocity = Vector3.zero; p.Body.angularVelocity = Vector3.zero; }
}
// per-tick CSV logger, self-terminating after 25 s of game time
string path = "C:/Projects/RNMechs/playtest/drive_log.csv";
System.IO.File.WriteAllText(path, "t,x,y,z,speed,yawdeg,angvel\n");
float t0 = Time.time;
float deadline = t0 + 25f;
int tick = 0;
UnityEditor.EditorApplication.CallbackFunction h = null;
h = () => {
    if (Time.time > deadline) { UnityEditor.EditorApplication.update -= h; return; }
    tick++;
    if (tick % 5 != 0) return;
    var s = UnityEngine.Object.FindAnyObjectByType<RNMechs.Simulation.SimulationController>();
    if (s == null || s.LiveMachine == null || s.LiveMachine.ChassisBody == null) return;
    var b = s.LiveMachine.ChassisBody;
    var f = b.transform.forward;
    float yaw = Mathf.Atan2(f.x, f.z) * Mathf.Rad2Deg;
    System.IO.File.AppendAllText(path,
        Time.time.ToString("F2") + "," + b.position.x.ToString("F2") + "," + b.position.y.ToString("F2") + "," + b.position.z.ToString("F2") + ","
        + b.linearVelocity.magnitude.ToString("F2") + "," + yaw.ToString("F1") + "," + b.angularVelocity.magnitude.ToString("F2") + "\n");
};
UnityEditor.EditorApplication.update += h;
return "logger started t0=" + t0.ToString("F2") + " car reseated to (0,1.5,5)";
