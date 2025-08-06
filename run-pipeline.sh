#!/bin/bash

set -e

# ========= Git Branch =========
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "📍 Current Git branch: $CURRENT_BRANCH"

# ========= Docker Image Setup =========
IMAGE="r20digital/php8.3-fpm:latest"
APP_DIR=$(pwd)
WORKSPACE_DIR=$(realpath ../)
CONTAINER_APP_DIR="$WORKSPACE_DIR/$(basename "$APP_DIR")"

DOCKER_RUN_FLAGS=(
  -v "$WORKSPACE_DIR:$WORKSPACE_DIR"
  -w "$CONTAINER_APP_DIR"
  --rm -it
)

# ========= Pull image if needed =========
if ! docker image inspect $IMAGE >/dev/null 2>&1; then
  echo "📦 Pulling Docker image: $IMAGE"
  docker pull $IMAGE
fi

# ========= Prompt: What to Run =========
echo ""
echo "What would you like to run?"
echo "1) Pest (all tests)"
echo "2) PHPStan"
echo "3) Both"
echo "4) Interactive shell"
echo "5) Specific Pest test file"
read -p "Select an option (1/2/3/4/5): " choice

# ========= Run Pest =========
if [[ "$choice" == "1" ]]; then
  echo "🧪 Running Pest..."
  docker run "${DOCKER_RUN_FLAGS[@]}" "$IMAGE" sh -c "
    git config --global --add safe.directory '$CONTAINER_APP_DIR' &&
    composer install &&
    composer dump-autoload &&
    php artisan key:generate &&
    vendor/bin/pest
  "
  exit 0
fi

# ========= Run PHPStan =========
if [[ "$choice" == "2" ]]; then
  echo "🔍 Running PHPStan..."
  docker run "${DOCKER_RUN_FLAGS[@]}" "$IMAGE" sh -c "
    git config --global --add safe.directory '$CONTAINER_APP_DIR' &&
    composer install &&
    composer dump-autoload &&
    php artisan key:generate &&
    vendor/bin/phpstan --memory-limit=1G
  "
  exit 0
fi

# ========= Run Both =========
if [[ "$choice" == "3" ]]; then
  echo "🔍 Running Pest + PHPStan..."
  docker run "${DOCKER_RUN_FLAGS[@]}" "$IMAGE" sh -c "
    git config --global --add safe.directory '$CONTAINER_APP_DIR' &&
    composer install &&
    composer dump-autoload &&
    php artisan key:generate &&
    echo '🧪 Running Pest...' &&
    vendor/bin/pest &&
    echo '🔍 Running PHPStan...' &&
    vendor/bin/phpstan --memory-limit=1G
  "
  exit 0
fi

# ========= Run Interactive Shell =========
if [[ "$choice" == "4" ]]; then
  echo "🐚 Starting interactive shell inside container..."
  docker run "${DOCKER_RUN_FLAGS[@]}" "$IMAGE" sh -c "
    git config --global --add safe.directory '$CONTAINER_APP_DIR' &&
    exec sh
  "
  echo "👋 Exited interactive shell."
  exit 0
fi

# ========= Run Specific Pest File =========
if [[ "$choice" == "5" ]]; then
  echo "🎯 Selecting a specific Pest test file..."

  if command -v fzf >/dev/null 2>&1; then
      TEST_FILE=$(find tests -type f -name '*Test.php' | fzf --prompt="Select a test file: ")
  else
      read -p "Enter test file to run (e.g. tests/Feature/UserTest.php): " TEST_FILE
  fi

  if [ -z "$TEST_FILE" ]; then
    echo "❌ No file selected. Aborting."
    exit 1
  fi

  echo "🧪 Running Pest on: $TEST_FILE"
  docker run "${DOCKER_RUN_FLAGS[@]}" "$IMAGE" sh -c "
    git config --global --add safe.directory '$CONTAINER_APP_DIR' &&
    composer install &&
    composer dump-autoload &&
    php artisan key:generate &&
    vendor/bin/pest $TEST_FILE
  "
  exit 0
fi

echo "✅ Pipeline completed on branch: $CURRENT_BRANCH"

