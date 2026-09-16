# Delivery and publication

## Default: conversation

Lead with the verdict and actionable findings, not a checklist transcript. For multiple PRs, provide a compact per-PR summary. Include:

- Reviewed revision/snapshot and material exclusions.
- Findings ordered by impact, with precise locations, reachable scenarios, evidence, and corrective direction.
- Checks performed and their outcomes, distinguished from author claims or existing CI. Give relevant failure output without leaking secrets or dumping unrelated logs.
- Remaining limitations or a narrow question if evidence is unavailable.

If a tool step failed but an alternate path succeeded, do not imply coverage was lost. If the diff remained truncated or a necessary consumer was inaccessible, do not give an unqualified clean verdict. "No findings" and "insufficient evidence to conclude" are different results.

## Optional: report file

Write only when requested, at the supplied path or an established repository location. Choose a new filename/version if a report already exists unless replacement is explicitly requested. Keep credentials, unnecessary local paths, and unrelated user data out of the report.

Do not mandate an `.agents/skills/outputs` directory or duplicate the entire review into a file by default. If deletion is requested, delete only the named artifact after inspecting it. When deletion follows publication, wait until every requested publication is confirmed so a failure does not discard the deliverable.

## Optional: GitHub review

Publish only with an explicit instruction such as "publish the review". Use `gh` or the available authorized GitHub interface.

1. Re-read the PR state, base and head SHAs, and recent reviews/comments. Confirm the destination repository/PR and authenticated identity. Do not infer the target from the local branch.
2. Compare current base/head against the reviewed snapshot. If either changed, review the intervening delta and revalidate affected findings before submitting a current verdict. If that cannot be done, state the drift and publish only an explicitly authorized historical comment pinned to the original revision; do not request changes or approve a new revision on stale evidence.
3. Submit each PR's own findings, pinning `commit_id` where supported. Prefer short inline anchors in the diff; use the review body for cross-file explanations or findings with no suitable inline anchor. Reference related PRs rather than copying irrelevant findings.
4. Use `REQUEST_CHANGES` for demonstrated regressions that warrant correction. Use `COMMENT` for a scoped nonblocking or no-findings report. Use `APPROVE` only when formal approval is requested or established by the user's workflow and material review gaps do not remain. Never submit an empty verdict as a substitute for review content.
5. Check the API result for state, commit, and URL. Creating a pending review is not publishing it. If a network response is ambiguous, query recent reviews before retrying to avoid duplicates. Do not automatically dismiss or overwrite earlier reviews.
6. Return the resulting URL for each PR and accurately report partial success or permission failures. Preserve local output until the requested publications are confirmed.

If the account cannot request changes on its own PR or lacks permission, report the limitation. A comment may communicate the findings but is not equivalent to a formal changes-requested review; do not claim it is.

## Optional: project conventions

Check branch routing, title tags, changelog rules, or commit structure only when requested or required by repository instructions. Source each rule from that project. Separate convention compliance from product defects and use its actual enforcement level.

Commit history can explain intent or isolate a regression. It cannot establish working hours, push timing, validation discipline, or developer competence. Do not flag long gaps, few commits, fix-up commits, or large commits as bugs. If size exceeds the available review capacity, report the specific unreviewed portion rather than claiming the patch is inherently incorrect.
