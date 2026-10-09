# Procedural building visual targets

The user requested imagegen references and actual renders grouped by style and room. All twelve published house styles have a saved four-panel exterior/room/prop board, its exact prompt, and interpretation notes. The gallery retains 72 prior reviewed Godot images and adds 24 public requests across the eight remaining styles, with roof-on exterior, representative functional room views and secondary cutaways. Each current run records exact requests, actual assembled prop transforms, model hashes, source fingerprints and native receipts.

Open [the house comparison gallery](../visualqa/styles/house/index.html). Concept boards live in `visualqa/styles/house/<style>/targets/`. Actual results live in `<style>/renders/<run>/<request>/rooms/` or `views/`. The index records image and source-manifest hashes. [Assistant findings](../visualqa/styles/house/assistant_review.json) describe the remaining defects; they are not human ratings.

Use the references to set proportions, silhouette, room hierarchy, useful wall runs, furniture relationships, and restrained decoration. Reduce incidental plants, herb bunches, and tabletop objects. Each group must serve an activity and retain its working approach. The generator must prove physical support, real openings, measured prop fit and walkability in its own mesh.

The references do not finish any building design task. All actual cohorts remain visually unaccepted. Across the eight new comparisons, cottage-like room divisions and the same generic furniture undermine the distinct exterior palettes. The Witch bedroom thought empty in one view is furnished in the actual plan; the problem there is readability and arrangement. Single room cameras sample an activity; they cannot prove that everything outside the frame is absent.

## Remaining reference coverage

House comparison coverage now includes all twelve styles. The new 24-request reference matrix does not replace the retained HouseStyles acceptance matrix of 111 requests and 666 views. Extend targets and actual comparisons to the published church, temple, shop, hotel, castle, windmill, world and village families. Gothic already has its board and scoped chapel-passage comparisons. Use a specific architectural brief per style rather than one generic building with alternate props. The broad cultural API labels have fictional, explicitly narrowed household briefs in their target notes; they do not establish cultural authenticity.

Room views must include arrival/circulation, cooking/work, living/eating, sleeping/privacy, storage, and service thresholds where those functions exist. Sacred buildings need entrance-to-ritual-axis and sanctuary views. Shops need customer, work and stock sequences. A decorated exterior cannot substitute for these interiors.

## Focused room and sacred targets

The [target catalogue](../visualqa/styles/index.html) also links the Pylon, Rotunda and Basilica temple boards and Gothic church board. Rotunda and Basilica are Temple API forms in this repository. Their current boards use the blood cult for comparison; the architectural form must remain recognisable across other cults. Each target note identifies generated inconsistencies and excess props to discard.

The [Cottage cooking reference](../visualqa/styles/house/cottage/rooms/cooking/targets/design_board_v1.png) focuses on a linked hearth, preparation surface, food storage and usable standing floor. Visible split fuel and a small irregular fire are part of the target. It does not approve the current procedural fire or establish measured trivet, vessel or combustible clearances.

The [Townhouse writing office reference](../visualqa/styles/house/townhouse/rooms/work/targets/design_board_v1.png) adds a compact desk, chair facing the writing edge, reachable ledger, nearby records and daylight. Keep the visible door route and chair pull-back space. Its dimensions are concept labels, not measurements of owned assets. Current office comparisons expose the next arrangement problem: a supported book at the far end of a large workbench does not establish a usable writing place. Eighteen boards are now saved with exact prompts and interpretation notes.

## Reusing the archive tool

`python tools/organize_visualqa_renders.py` prints a dry-run plan for the two legacy cohorts. Add `--apply` to copy. For more cohorts, repeat `--source <render-directory> <run-name>` and include all desired cohorts when rebuilding the gallery. Already nested images stay at their exact path. Source identity includes the manifest path and hash, so eight styles can share a run name without acquiring one another's metadata. The tool refuses changed image destinations and escaped source paths, checks hashes, and preserves existing human ratings, walk pins and the rating selector.

Verification: the 72 legacy images and five exact source-manifest copies remain preserved. Every image in the eight new runs was opened by root and has a SHA-256 record in its assistant review. All eight native render runs exited zero, retained all three sizes, matched source fingerprints before/after, and assembled all planned props. The organizer's source-association, legacy-status and path-boundary checks passed. Twelve generated boards, prompts and notes were saved. Geometry, support, ventilation and circulation errors visible in generated concepts are called out in each target note rather than treated as implementation instructions.
