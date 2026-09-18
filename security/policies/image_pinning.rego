# Policy for this repository's Dockerfiles: every image pulled from a registry
# is pinned by digest, the same rule the workflows follow for their images.

package dockerfile

# `conftest parse` prints an outer array, but `test` evaluates each element on
# its own, so `input` is the flat list of instructions.
instructions contains instruction if some instruction in input

# --- Base images are pinned by digest ----------------------------------------
#
# A registry tag is a movable pointer; a digest names exactly one image.

deny contains msg if {
	some instruction in instructions
	instruction.Cmd == "from"
	image := instruction.Value[0]
	not exempt(image)
	not digest_pinned(image)
	msg := sprintf(
		"stage %d `FROM %s`: pin by `@sha256:` digest, not by tag",
		[instruction.Stage, image],
	)
}

# --- Images copied from are pinned by digest ---------------------------------
#
# `COPY --from=<image>` pulls a registry image into the build like a base image.

deny contains msg if {
	some instruction in instructions
	instruction.Cmd == "copy"
	some flag in instruction.Flags
	startswith(flag, "--from=")
	source := trim_prefix(flag, "--from=")
	not exempt(source)
	not digest_pinned(source)
	msg := sprintf(
		"stage %d `COPY --from=%s`: pin by `@sha256:` digest, not by tag",
		[instruction.Stage, source],
	)
}

# Names declared by `FROM <image> AS <name>`, which Docker matches case-insensitively.
stage_aliases contains lower(instruction.Value[2]) if {
	some instruction in instructions
	instruction.Cmd == "from"
	count(instruction.Value) == 3
	lower(instruction.Value[1]) == "as"
}

# Not registry pulls: the empty base image, and earlier stages by name or index.
exempt(image) if lower(image) == "scratch"

exempt(image) if lower(image) in stage_aliases

exempt(image) if regex.match(`^[0-9]+$`, image)

digest_pinned(image) if regex.match(`@sha256:[0-9a-f]{64}$`, image)
