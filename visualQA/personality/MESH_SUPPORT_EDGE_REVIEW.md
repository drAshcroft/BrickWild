# Closed-edge support measurement

A vertical ray could miss the shared edge between two emitted floor triangles. The support probe now treats projected triangles as closed sets with a fixed 50 micrometre edge tolerance. It interpolates the actual triangle height and retains upward winding and degeneracy checks. It does not create or move geometry.

Root inspected the implementation and Luna independently reviewed it. The focused fixture measures actual MeshKit slabs, including shared edges, outer vertices, diagonals and interior points. It removes every real triangle supporting the same point and requires support to disappear. Points 1 mm beyond the floor, wrong heights, downward faces, degenerate triangles and steep walls must fail.

| Native receipt | Result | Host seconds |
|---|---|---:|
| restart9_mesh_support_far_edge | 239 checks, zero failures; widths 1/11.67208/80 m; origin and translations 500 m and 2 km | 0.872 |
| restart8_mesh_support_world_consumers | 43 checks, zero failures and warnings; hammam, Nagara, stepwell, temple mountain and Dravida | 53.142 |
| restart8_mesh_support_sacred_consumers | Full existing sacred structural fixture; zero failures | 54.257 |

All receipts have native exit 0 and no invalid engine result. Logs are under artifacts/personality/resumed/<receipt>/. No full API sweep or geometry change is claimed. The 2 km samples establish tested cases, not an arbitrary-coordinate precision guarantee. Rotunda architecture and Witch identity remain unaccepted.
