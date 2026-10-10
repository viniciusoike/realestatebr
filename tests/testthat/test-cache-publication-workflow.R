test_that("the targets store is saved only after successful publication", {
  workflow_path <- test_path(
    "..",
    "..",
    ".github",
    "workflows",
    "update_data_weekly.yml"
  )
  skip_if_not(
    file.exists(workflow_path),
    "Workflow is not included in the built package"
  )
  workflow <- yaml::read_yaml(workflow_path)
  steps <- workflow$jobs$`update-data`$steps
  names <- vapply(steps, `[[`, character(1), "name")

  upload <- match("Upload cached datasets to GitHub release", names)
  save <- match("Save targets store", names)
  report <- match("Report completion", names)

  expect_false(anyNA(c(upload, save, report)))
  expect_gt(save, upload)
  expect_lt(save, report)
  expect_match(steps[[save]]$`if`, "success\\(\\)")
  expect_match(
    steps[[save]]$`if`,
    "steps.pipeline.outputs.targets_failed != 'true'",
    fixed = TRUE
  )
})
