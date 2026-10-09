# Procedural building visual targets

The user requested imagegen references and actual renders grouped by style and room. The first domestic comparison task is complete: Witch hut, cottage, farmhouse, and thatched cottage each have a saved four-panel exterior/room/prop board, its exact prompt, and interpretation notes. All 72 reviewed Godot images are copied into the same style tree with unchanged pixels and source manifests.

Open [the house comparison gallery](../visualqa/styles/house/index.html). Concept boards live in `visualqa/styles/house/<style>/targets/`. Actual results live in `<style>/renders/<run>/<request>/rooms/` or `views/`. The index records image and source-manifest hashes. [Assistant findings](../visualqa/styles/house/assistant_review.json) describe the remaining defects; they are not human ratings.

Use the references to set proportions, silhouette, room hierarchy, useful wall runs, furniture relationships, and restrained decoration. Reduce incidental plants, herb bunches, and tabletop objects. Each group must serve an activity and retain its working approach. The generator must prove physical support, real openings, measured prop fit and walkability in its own mesh.

The references do not finish any building design task. The two actual cohorts remain visually unaccepted. The Witch bedroom thought empty in one view is furnished in the actual plan; the problem there is readability and arrangement.

## Remaining reference coverage

Extend this workflow to townhouse, longhall, rich, Mediterranean, Asian, African, mud-hut and Pueblo style rows, then the published church, temple, shop, hotel, castle, windmill, world and village families. Use a specific architectural brief per style rather than one generic building with alternate props. Cultural labels in the existing API need more precise reference briefs before making authenticity claims.

Room views must include arrival/circulation, cooking/work, living/eating, sleeping/privacy, storage, and service thresholds where those functions exist. Sacred buildings need entrance-to-ritual-axis and sanctuary views. Shops need customer, work and stock sequences. A decorated exterior cannot substitute for these interiors.

## Reusing the archive tool

`python tools/organize_visualqa_renders.py` prints a dry-run plan for the two current cohorts. Add `--apply` to copy. For another cohort, repeat `--source <render-directory> <unique-run-name>`. Include all desired cohorts when rebuilding the gallery. The tool refuses changed image destinations, checks copied hashes, and preserves the existing human ratings, walk pins and rating selector.

Verification: 72 unique destination files matched their source SHA-256 values; five style/run copies matched their exact source manifests; four generated boards, prompts and notes were saved. Root inspected all 72 actual images and all four targets.
