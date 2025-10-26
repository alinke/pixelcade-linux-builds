#!/bin/bash

PAT="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"

download_artifact()
{
    local REPO="$1"
    local TOKEN="$2"
    local BRANCH="$3"
    local WORKFLOW_NAME="$4"
    local KEY="$5"

                        #| select(.conclusion=="success" and .name==$workflow)
                        #| .id
    local RUN_IDS=$(curl -s -H "Authorization: token $TOKEN" \
                      -H "Accept: application/vnd.github.v3+json" \
                      "https://api.github.com/repos/$REPO/actions/runs?branch=$BRANCH" | \
                      jq --arg workflow "$WORKFLOW_NAME" -r '
                        .workflow_runs[]
                        | select(.name==$workflow)
                        | .id
                      ')

    if [[ -z "$RUN_IDS" ]]; then
        echo "No successful runs for branch $BRANCH and workflow $WORKFLOW_NAME."
        exit 1
    fi

    local FOUND_ARTIFACT=""
    local FOUND_RUN_ID=""

    for RUN_ID in $RUN_IDS; do
        ARTIFACT_DATA=$(curl -s -H "Authorization: token $TOKEN" \
                          -H "Accept: application/vnd.github.v3+json" \
                          "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/artifacts" | \
                          jq --arg key "$KEY" '
                            .artifacts[]
                            | select(.name==$key or (.name | contains($key)))
                          ')

        if [[ -n "$ARTIFACT_DATA" && "$ARTIFACT_DATA" != "null" ]]; then
            FOUND_ARTIFACT="$ARTIFACT_DATA"
            FOUND_RUN_ID="$RUN_ID"
            break
        fi
    done

    if [[ -z "$FOUND_ARTIFACT" ]]; then
        echo "No artifact matching \"$KEY\" found in any recent successful run."
        exit 1
    fi

    ARTIFACT_NAME=$(echo "$FOUND_ARTIFACT" | jq -r '.name')
    local ARTIFACT_URL=$(echo "$FOUND_ARTIFACT" | jq -r '.archive_download_url')

    mkdir -p /userdata/system/configs/vpinball/"$ARTIFACT_NAME"
    cd /userdata/system/configs/vpinball/"$ARTIFACT_NAME"

    echo "Downloading ${ARTIFACT_NAME} from run $FOUND_RUN_ID..."
    curl -L -o "${ARTIFACT_NAME}.zip" -H "Authorization: token $TOKEN" "$ARTIFACT_URL"

    echo "Uncompressing ${ARTIFACT_NAME}..."
    unzip -q "${ARTIFACT_NAME}.zip"
    tar xzvf "${ARTIFACT_NAME}.tar.gz"

    rm "${ARTIFACT_NAME}.zip" "${ARTIFACT_NAME}.tar.gz"
}

#
# Download
#

download_artifact "vpinball/vpinball" "$PAT" "standalone" "vpinball" "Release-linux-x64"

#
# Install symlink
#

rm -rf /usr/bin/vpinball
ln -s "/userdata/system/configs/vpinball/${ARTIFACT_NAME}" /usr/bin/vpinball
rm /userdata/system/configs/vpinball/${ARTIFACT_NAME}/libSDL2-*
rm /userdata/system/configs/vpinball/${ARTIFACT_NAME}/libSDL2.so

#
# Save overlay
#

batocera-save-overlay 200
