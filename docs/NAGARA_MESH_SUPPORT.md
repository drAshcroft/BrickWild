# Nagara gallery and stair mesh support

`ShikharaCheck` now probes upward-facing emitted triangles on each of the four
pradakshina floor strips and every planned entrance tread. Plan connectivity and
mass logs alone cannot provide this evidence. Callers may supply a completed
mesh; builder-only checks read its emitted SurfaceTool arrays. Plan-only axis
and ring checks remain available.

```powershell
& tools/run_qa_lane.ps1 -Selectors wld013,nagaramesh
```

The new fixture removes actual top triangles from a gallery strip and a tread
while retaining the mass and part logs. Each missing surface must fail the
production checker. The existing family gate includes the public API's quality
report, generation and instantiation, plus its original semantic controls.

On 3 October 2026 the two suites passed thirteen checks with zero failures or
warnings, native exit 0, in 30.52 seconds. Evidence:
`artifacts/qa_fast/wld013__nagaramesh/20261003_005429`.
This proves bounded support coverage; the Mountain, stepwell and Dravida mesh
audits and the affected-family visual reviews remain open.
