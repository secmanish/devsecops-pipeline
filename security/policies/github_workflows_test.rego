package github.workflows

pinned_sha := "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1"

pinned_image := "semgrep/semgrep:1.177.0@sha256:acaac22ffc7b7cc5926de0751b223bce0b2491c33d18422fa72f632c78d81198"

# A workflow that satisfies every rule, used as the baseline the focused tests
# vary one field at a time.
workflow_with_job(job) := {
	"on": {"pull_request": null},
	"permissions": {"contents": "read"},
	"jobs": {"scan": job},
}

workflow_with_steps(steps) := workflow_with_job({"steps": steps})

test_compliant_workflow_passes if {
	messages := deny with input as workflow_with_steps([
		{"uses": pinned_sha},
		{"name": "Scan", "run": "echo scanning"},
	])
	count(messages) == 0
}

# --- Pinning ------------------------------------------------------------------

test_action_pinned_to_tag_denied if {
	messages := deny with input as workflow_with_steps([{"uses": "actions/checkout@v7"}])
	count(messages) == 1
	some msg in messages
	contains(msg, "pin to a 40-character commit SHA")
}

test_action_pinned_to_branch_denied if {
	messages := deny with input as workflow_with_steps([{"uses": "actions/checkout@main"}])
	count(messages) == 1
}

# A short SHA is still ambiguous: it can be extended to collide.
test_action_pinned_to_short_sha_denied if {
	messages := deny with input as workflow_with_steps([{"uses": "actions/checkout@3d3c42e"}])
	count(messages) == 1
}

test_local_action_allowed if {
	messages := deny with input as workflow_with_steps([{"uses": "./.github/actions/setup"}])
	count(messages) == 0
}

test_docker_action_with_digest_allowed if {
	messages := deny with input as workflow_with_steps([{"uses": "docker://ghcr.io/example/scanner@sha256:acaac22ffc7b7cc5926de0751b223bce0b2491c33d18422fa72f632c78d81198"}])
	count(messages) == 0
}

test_docker_action_with_tag_denied if {
	messages := deny with input as workflow_with_steps([{"uses": "docker://ghcr.io/example/scanner:1.2.3"}])
	count(messages) == 1
}

test_reusable_workflow_pinned_to_tag_denied if {
	messages := deny with input as {
		"on": {"pull_request": null},
		"permissions": {"contents": "read"},
		"jobs": {"scan": {"uses": "example/repo/.github/workflows/scan.yml@v1"}},
	}
	count(messages) == 1
}

# A step with no `uses` key has nothing to pin. Rego treats a negated call on an
# undefined argument as true, so this is the rule's easiest way to go wrong.
test_run_only_step_not_flagged_as_unpinned if {
	messages := deny with input as workflow_with_steps([{"run": "echo hello"}])
	count(messages) == 0
}

# --- Permissions --------------------------------------------------------------

test_missing_permissions_denied if {
	messages := deny with input as {
		"on": {"pull_request": null},
		"jobs": {"scan": {"steps": [{"run": "echo hello"}]}},
	}
	count(messages) == 1
	some msg in messages
	contains(msg, "permissions")
}

test_empty_permissions_allowed if {
	messages := deny with input as {
		"on": {"pull_request": null},
		"permissions": {},
		"jobs": {"scan": {"steps": [{"run": "echo hello"}]}},
	}
	count(messages) == 0
}

# --- Triggers -----------------------------------------------------------------

test_pull_request_target_denied if {
	messages := deny with input as {
		"on": {"pull_request_target": null},
		"permissions": {"contents": "read"},
		"jobs": {"scan": {"steps": [{"run": "echo hello"}]}},
	}
	count(messages) == 1
	some msg in messages
	contains(msg, "pull_request_target")
}

# `on:` is a YAML 1.1 boolean, so the key can reach the policy as `true`.
test_pull_request_target_denied_when_key_is_boolean if {
	messages := deny with input as {
		true: {"pull_request_target": null},
		"permissions": {"contents": "read"},
		"jobs": {"scan": {"steps": [{"run": "echo hello"}]}},
	}
	count(messages) == 1
}

test_pull_request_target_denied_in_list_form if {
	messages := deny with input as {
		"on": ["push", "pull_request_target"],
		"permissions": {"contents": "read"},
		"jobs": {"scan": {"steps": [{"run": "echo hello"}]}},
	}
	count(messages) == 1
}

test_single_string_trigger_allowed if {
	messages := deny with input as {
		"on": "push",
		"permissions": {"contents": "read"},
		"jobs": {"scan": {"steps": [{"run": "echo hello"}]}},
	}
	count(messages) == 0
}

# --- Container images ---------------------------------------------------------

test_container_image_with_digest_allowed if {
	messages := deny with input as workflow_with_job({
		"container": {"image": pinned_image},
		"steps": [{"run": "echo hello"}],
	})
	count(messages) == 0
}

test_container_image_with_tag_denied if {
	messages := deny with input as workflow_with_job({
		"container": {"image": "semgrep/semgrep:1.177.0"},
		"steps": [{"run": "echo hello"}],
	})
	count(messages) == 1
	some msg in messages
	contains(msg, "@sha256:")
}

test_container_as_bare_string_denied if {
	messages := deny with input as workflow_with_job({
		"container": "semgrep/semgrep:1.177.0",
		"steps": [{"run": "echo hello"}],
	})
	count(messages) == 1
}

# A job with no `container` key has no image to pin: the undefined-argument trap
# again, guarded in a second rule.
test_job_without_container_not_flagged if {
	messages := deny with input as workflow_with_job({"steps": [{"run": "echo hello"}]})
	count(messages) == 0
}

test_service_image_with_tag_denied if {
	messages := deny with input as workflow_with_job({
		"services": {"postgres": {"image": "postgres:16"}},
		"steps": [{"run": "echo hello"}],
	})
	count(messages) == 1
	some msg in messages
	contains(msg, "postgres")
}

test_service_image_with_digest_allowed if {
	messages := deny with input as workflow_with_job({
		"services": {"postgres": {"image": "postgres:16@sha256:acaac22ffc7b7cc5926de0751b223bce0b2491c33d18422fa72f632c78d81198"}},
		"steps": [{"run": "echo hello"}],
	})
	count(messages) == 0
}

# --- Script injection ---------------------------------------------------------

test_untrusted_context_in_run_denied if {
	messages := deny with input as workflow_with_steps([{
		"run": "echo ${{ github.event.pull_request.title }}",
	}])
	count(messages) == 1
	some msg in messages
	contains(msg, "${{ github.event.pull_request.title }}")
	contains(msg, "bind it to `env:`")
}

# The ban is on the interpolation itself, not on a list of dangerous fields.
test_safe_context_in_run_also_denied if {
	messages := deny with input as workflow_with_steps([{"run": "echo ${{ github.sha }}"}])
	count(messages) == 1
}

# An expression containing a `}` must not truncate the match and slip past.
test_expression_containing_brace_denied if {
	messages := deny with input as workflow_with_steps([{
		"run": "echo ${{ format('{0}', github.head_ref) }}",
	}])
	count(messages) == 1
	some msg in messages
	contains(msg, "format('{0}', github.head_ref)")
}

test_two_expressions_reported_separately if {
	messages := deny with input as workflow_with_steps([{
		"run": "echo ${{ github.sha }} ${{ github.head_ref }}",
	}])
	count(messages) == 1
	some msg in messages
	contains(msg, "${{ github.sha }}, ${{ github.head_ref }}")
}

# The same value is safe once the shell receives it as a variable rather than as
# text spliced into the script. `env:` is not scanned, only `run:`.
test_context_passed_through_env_allowed if {
	messages := deny with input as workflow_with_steps([{
		"env": {"TITLE": "${{ github.event.pull_request.title }}"},
		"run": "echo \"$TITLE\"",
	}])
	count(messages) == 0
}

test_shell_variable_in_run_allowed if {
	messages := deny with input as workflow_with_steps([{
		"run": "curl -sSfL \"https://example.com/v${VERSION}/tool.tar.gz\"",
	}])
	count(messages) == 0
}
