#!/usr/bin/env bash

# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script compiles manifest files with the image tags and places them in
# /release/...

set -euo pipefail
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

log() { echo "$1" >&2; }

TAG="${TAG:?TAG env variable must be specified}"
REPO_PREFIX="${REPO_PREFIX:?REPO_PREFIX env variable must be specified}"
OUT_DIR="${OUT_DIR:-${SCRIPTDIR}/../release}"

print_license_header() {
    cat "${SCRIPTDIR}/license_header.txt"
    echo
}

print_autogenerated_warning() {
    cat<<EOF
# ----------------------------------------------------------
# WARNING: This file is autogenerated. Do not manually edit.
# ----------------------------------------------------------

EOF
}

# define gsed as a function on Linux for compatibility
[ "$(uname -s)" == "Linux" ] && gsed() {
    sed "$@"
}

read_manifests() {
    local dir
    dir="$1"

    while IFS= read -d $'\0' -r file; do
        echo "---"

        # strip license headers (pattern "^# ")
        awk '
        /^[^# ]/ { found = 1 }
        found { print }' "${file}"
    done < <(find "${dir}" -name '*.yaml' -type f -print0)
}

mk_kubernetes_manifests() {
    out_manifest="$(read_manifests "${SCRIPTDIR}/../kubernetes-manifests")"

    # replace "image" repo, tag for each service
    for dir in ./src/*/
    do
        svcname="$(basename "${dir}")"
        image="$REPO_PREFIX/$svcname:$TAG"

        pattern="^(\s*)image:\s.*$svcname(.*)(\s*)"
        replace="\1image: $image\3"
        out_manifest="$(gsed -r "s|$pattern|$replace|g" <(echo "${out_manifest}") )"
    done

    print_license_header
    print_autogenerated_warning
    echo '# [START gke_release_kubernetes_manifests_microservices_demo]'
    echo "${out_manifest}"
    echo "# [END gke_release_kubernetes_manifests_microservices_demo]"
}

mk_istio_manifests() {
    print_license_header
    print_autogenerated_warning
    echo '# [START servicemesh_release_istio_manifests_microservices_demo]'
    read_manifests "${SCRIPTDIR}/../istio-manifests"
    echo '# [END servicemesh_release_istio_manifests_microservices_demo]'
}

mk_kustomize_base() {
  for file_to_copy in ./kubernetes-manifests/*.yaml
  do
    cp ${file_to_copy} ./kustomize/base/

    service_name="$(basename "${file_to_copy}" .yaml)"
    image="$REPO_PREFIX/$service_name:$TAG"

    # Inside redis.yaml, we use the official `redis:alpine` Docker image.
    # We don't use an image from `gcr.io/google-samples/microservices-demo`.
    if [[ $service_name == "redis" ]]; then
      continue
    fi

    pattern="^(\s*)image:\s.*${service_name}(.*)(\s*)"
    replace="\1image: ${image}\3"
    gsed --in-place --regexp-extended "s|${pattern}|${replace}|g" ./kustomize/base/${service_name}.yaml
  done
}

main() {
    mkdir -p "${OUT_DIR}"
    local k8s_manifests_file istio_manifests_file

    k8s_manifests_file="${OUT_DIR}/kubernetes-manifests.yaml"
    mk_kubernetes_manifests > "${k8s_manifests_file}"
    log "Written ${k8s_manifests_file}"

    istio_manifests_file="${OUT_DIR}/istio-manifests.yaml"
    mk_istio_manifests > "${istio_manifests_file}"
    log "Written ${istio_manifests_file}"

    mk_kustomize_base
    log "Written Kustomize base"
}

main
