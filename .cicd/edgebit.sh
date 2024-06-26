set -ex

# Check for required env vars
if [[ -z "$EDGEBIT_API_KEY" ]]; then
  echo "EDGEBIT_API_KEY env var is required"
  exit 1
fi

# Parse flags
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --repo) REPO="$2"; shift ;;
        --local-image) LOCAL_IMAGE="$2"; shift ;;
        --remote-image) REMOTE_IMAGE="$2"; shift ;;
        --component-name) COMPONENT="$2"; shift ;;
        --version) IMAGE_TAG="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Install latest ebctl
curl -sL https://install.edgebit.io/releases/edgebit-cli/latest/edgebit-cli_Linux_x86_64.tar.gz --output ebctl.tar.gz
tar -xvf ebctl.tar.gz
chmod +x ebctl

# Install syft v1.4.0
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b . v1.4.0

# Install time
sudo yum --quiet install time -y

# Gather GitHub details
LATEST_SHA=$(git rev-parse HEAD)
GITHUB_PULL_REQUEST=$(echo "${CODEBUILD_WEBHOOK_TRIGGER}" | sed -e "s/^pr\///")
if [ "${CODEBUILD_WEBHOOK_EVENT}" = "PULL_REQUEST_MERGED" ] && [ "${CODEBUILD_WEBHOOK_BASE_REF}" = "refs/heads/main" ]; then
  EDGEBIT_EXTRA_TAG="--tag latest"
elif [[ -n "$GITHUB_PULL_REQUEST" ]]; then
  EDGEBIT_EXTRA_TAG="--tag pr-${GITHUB_PULL_REQUEST}"
fi
echo "$EDGEBIT_EXTRA_TAG"

# Generate SBOM and log timing info
$(which time) -v ./syft scan $LOCAL_IMAGE \
    --config ./cicd/container-syft.yaml \
    --output spdx-json=$COMPONENT.spdx.json

# Upload SBOM for diff-ing
./ebctl upload-sbom \
  --component "$COMPONENT" \
  --tag "$IMAGE_TAG" \
  $EDGEBIT_EXTRA_TAG \
  --repo "$REPO" \
  --commit "$LATEST_SHA" \
  --image-tag "$REMOTE_IMAGE" \
  --image-id $(docker image inspect --format '{{.ID}}' $LOCAL_IMAGE) \
  --repo-digest $(docker image inspect --format '{{join .RepoDigests ","}}' $LOCAL_IMAGE) \
  --pull-request "$GITHUB_PULL_REQUEST" \
  "$COMPONENT.spdx.json"
