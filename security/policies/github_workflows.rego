# Policy for this repository's own GitHub Actions workflows: conventions the
# workflows already follow, enforced by a gate rather than by memory.

package github.workflows

# --- Third-party actions are pinned to a commit SHA --------------------------
#
# A tag is a movable pointer; a 40-character commit SHA is not, so a review of
# the action's code stays valid until the pin is deliberately bumped.

deny contains msg if {
	some job_name, job in input.jobs
	some index, step in job.steps
	ref := step.uses
	not pinned(ref)
	msg := sprintf(
		"job %q step %d uses %q: pin to a 40-character commit SHA, not a tag or branch",
		[job_name, index, ref],
	)
}

# Reusable workflows are called at the job level rather than inside `steps`,
# and carry the same supply-chain risk.
deny contains msg if {
	some job_name, job in input.jobs
	ref := job.uses
	not pinned(ref)
	msg := sprintf(
		"job %q uses %q: pin to a 40-character commit SHA, not a tag or branch",
		[job_name, ref],
	)
}

# A path inside this repository: there is no third party to pin.
pinned(ref) if startswith(ref, "./")

# Container actions are pinned by image digest instead of by commit.
pinned(ref) if {
	startswith(ref, "docker://")
	regex.match(`@sha256:[0-9a-f]{64}$`, ref)
}

pinned(ref) if regex.match(`@[0-9a-f]{40}$`, ref)

# --- Every workflow declares its token scope ---------------------------------
#
# Without a `permissions` block the job inherits the repository default, which
# is broader than any single workflow needs.

deny contains msg if {
	not input.permissions
	msg := "no top-level `permissions` block: declare the least privilege this workflow needs"
}

# --- `pull_request_target` is banned -----------------------------------------
#
# It runs in the base repository's context with a write-scoped token on code the
# pull request author controls. `pull_request` does the same job read-only.

deny contains msg if {
	"pull_request_target" in triggers
	msg := "`pull_request_target` grants a write-scoped token to fork-authored code: use `pull_request`"
}

# YAML 1.1 reads a bare `on` as the boolean true, and parsers disagree on
# whether the key survives as "on", "true" or true. Accept all three.
trigger_keys := {"on", "true", true}

on_value := value if {
	some key, value in input
	key in trigger_keys
}

# on:
#   pull_request:
triggers contains name if {
	is_object(on_value)
	some name, _ in on_value
}

# on: [push, pull_request]
triggers contains name if {
	is_array(on_value)
	some name in on_value
}

# on: push
triggers contains on_value if is_string(on_value)

# --- Container images are pinned by digest -----------------------------------
#
# A job container is a supply-chain input like an action, and a registry tag is
# as movable as a git one.

deny contains msg if {
	some job_name, job in input.jobs
	image := container_image(job.container)
	not digest_pinned(image)
	msg := sprintf(
		"job %q container image %q: pin by `@sha256:` digest, not by tag",
		[job_name, image],
	)
}

deny contains msg if {
	some job_name, job in input.jobs
	some service_name, service in job.services
	image := container_image(service)
	not digest_pinned(image)
	msg := sprintf(
		"job %q service %q image %q: pin by `@sha256:` digest, not by tag",
		[job_name, service_name, image],
	)
}

# `container:` takes either a bare image string or a mapping with an `image` key.
container_image(spec) := spec if is_string(spec)

container_image(spec) := spec.image if is_object(spec)

digest_pinned(image) if regex.match(`@sha256:[0-9a-f]{64}$`, image)

# --- No `${{ }}` interpolation inside `run:` ---------------------------------
#
# GitHub substitutes before the shell parses, so an attacker-controlled value
# arrives as code. Banning every expression keeps the rule from going stale.

deny contains msg if {
	some job_name, job in input.jobs
	some index, step in job.steps
	contains(step.run, "${{")
	expressions := regex.find_n(`\$\{\{.*?\}\}`, step.run, -1)
	msg := sprintf(
		"job %q step %d interpolates %s into `run:`: bind it to `env:` and reference it as \"$VAR\"",
		[job_name, index, concat(", ", expressions)],
	)
}
