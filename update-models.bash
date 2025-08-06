#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

HTML="$(curl --no-progress-meter https://ollama.com/search)"

models() {
	echo "$HTML" |
		htmlq 'a[href^="/library/"]' --attribute href |
		sed 's/^\/library\///'
}

model_has_latest_tag() {
	[ "$1" != "wizardlm" ]
}

tags() {
	if model_has_latest_tag "$1"; then
		echo "latest"
	fi
	echo "$HTML" |
		htmlq "a[href=\"/library/$1\"] > div:nth-child(2) > div:nth-child(1) > span.text-blue-600" --text
}

pull() {
	local model=$1
	local tag=$2
	local output=$3
	echo "+ pull $model:$tag"
	curl --fail \
		--location \
		--show-error \
		--silent \
		--header "Accept: application/vnd.docker.distribution.manifest.v2+json" \
		"https://registry.ollama.ai/v2/library/$model/manifests/$tag" \
		--create-dirs \
		--output "$output"
	jq --sort-keys <"$output" >"${output}~"
	mv "${output}~" "$output"
}

for model in $(models); do
	mkdir -p "public/$model"
	for tag in $(tags "$model"); do
		touch "public/$model/$tag.json"
		if ! pull "$model" "$tag" "./public/$model/$tag.json"; then
			echo "Failed to update $model:$tag" >&2
			rm -f "public/$model/$tag.json"
			rmdir "public/$model" 2>/dev/null || true
		fi
	done
done
