package dockerfile

pinned_image := "python:3.14.7-slim@sha256:cad9a2c871761c413caa6fdd6441c783451e740a48aaeba60ae62a8b53525ef6"

pinned_copy_source := "ghcr.io/astral-sh/uv:0.12.15@sha256:62f8c047d0a0e9ece6b53fc63df902585a67a47a7f318ddec4a37db586edc8e3"

# Instructions in the shape `conftest test` hands the policy.
from(value, stage) := {"Cmd": "from", "Flags": [], "Stage": stage, "Value": value}

copy(flags, stage) := {"Cmd": "copy", "Flags": flags, "Stage": stage, "Value": ["/src", "/dest"]}

# The shape of the repository's own multi-stage builds.
test_compliant_multi_stage_build_passes if {
	messages := deny with input as [
		from([pinned_image, "AS", "builder"], 0),
		copy([concat("", ["--from=", pinned_copy_source])], 0),
		from([pinned_image], 1),
		copy(["--from=builder", "--chown=app:app"], 1),
	]
	count(messages) == 0
}

# --- FROM ---------------------------------------------------------------------

test_from_tag_denied if {
	messages := deny with input as [from(["python:3.14.7-slim"], 0)]
	count(messages) == 1
	some msg in messages
	contains(msg, "stage 0 `FROM python:3.14.7-slim`: pin by `@sha256:` digest")
}

test_from_without_tag_denied if {
	messages := deny with input as [from(["python"], 0)]
	count(messages) == 1
}

test_from_truncated_digest_denied if {
	messages := deny with input as [from(["python@sha256:cad9a2c8"], 0)]
	count(messages) == 1
}

# A build argument cannot be resolved by reading the file.
test_from_build_arg_denied if {
	messages := deny with input as [from(["${BASE_IMAGE}"], 0)]
	count(messages) == 1
}

test_from_digest_without_tag_allowed if {
	messages := deny with input as [from(["python@sha256:cad9a2c871761c413caa6fdd6441c783451e740a48aaeba60ae62a8b53525ef6"], 0)]
	count(messages) == 0
}

test_from_with_platform_flag_allowed if {
	messages := deny with input as [{
		"Cmd": "from",
		"Flags": ["--platform=linux/amd64"],
		"Stage": 0,
		"Value": [pinned_image],
	}]
	count(messages) == 0
}

test_from_scratch_allowed if {
	messages := deny with input as [from(["scratch"], 0)]
	count(messages) == 0
}

test_from_earlier_stage_allowed if {
	messages := deny with input as [
		from([pinned_image, "AS", "build"], 0),
		from(["build"], 1),
	]
	count(messages) == 0
}

test_stage_alias_case_insensitive if {
	messages := deny with input as [
		from([pinned_image, "as", "Build"], 0),
		from(["BUILD"], 1),
	]
	count(messages) == 0
}

test_stage_number_in_message if {
	messages := deny with input as [
		from([pinned_image, "AS", "build"], 0),
		from(["node:24-slim"], 1),
	]
	count(messages) == 1
	some msg in messages
	startswith(msg, "stage 1 ")
}

# --- COPY --from ----------------------------------------------------------------

test_copy_from_tag_denied if {
	messages := deny with input as [
		from([pinned_image], 0),
		copy(["--from=ghcr.io/astral-sh/uv:latest"], 0),
	]
	count(messages) == 1
	some msg in messages
	contains(msg, "stage 0 `COPY --from=ghcr.io/astral-sh/uv:latest`: pin by `@sha256:` digest")
}

test_copy_from_pinned_image_allowed if {
	messages := deny with input as [
		from([pinned_image], 0),
		copy([concat("", ["--from=", pinned_copy_source])], 0),
	]
	count(messages) == 0
}

test_copy_from_stage_index_allowed if {
	messages := deny with input as [
		from([pinned_image], 0),
		from([pinned_image], 1),
		copy(["--from=0"], 1),
	]
	count(messages) == 0
}

test_copy_from_stage_alias_allowed if {
	messages := deny with input as [
		from([pinned_image, "AS", "builder"], 0),
		from([pinned_image], 1),
		copy(["--from=builder"], 1),
	]
	count(messages) == 0
}

test_copy_without_from_ignored if {
	messages := deny with input as [
		from([pinned_image], 0),
		copy(["--chown=app:app"], 0),
	]
	count(messages) == 0
}
