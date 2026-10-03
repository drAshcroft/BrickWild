# Hammam dome mesh support

`HammamCheck` measures eight elevated roof-triangle intersections around each
cold, warm and hot room. The probes stay above the flat roof plane and away
from the crown oculi. A dome mass or component entry alone cannot satisfy them.
Plan-only checks remain supported; supplying a builder requires its emitted mesh.

Run the focused fixture with the existing family rules:

```powershell
& tools/run_qa_lane.ps1 -Selectors wld005,hammammesh
```

The new fixture removes the warm dome's elevated roof triangles while retaining
all mass and component logs. The missing dome must fail the production check.
The existing family suite continues to inspect oculus rays and its semantic
negative controls.

On 3 October 2026 both suites passed in the combined root gate
`artifacts/qa_fast/cmotteaccess__cmotteroute__wld005__hammammesh/20261003_002809`.
The complete command took 176.81 seconds and exited 0. This proves the bounded
hammam slice; Nagara, Mountain, stepwell and Dravida mesh audits remain open.
