#!/usr/bin/env bash
# Vercel build script for the Flutter web app.
#
# Vercel's build image has no Flutter SDK, so we install it here, then build.
# Configured via vercel.json:
#   "buildCommand": "bash scripts/vercel_build.sh"
#   "outputDirectory": "build/web"
set -euo pipefail

# ---------------------------------------------------------------------------
# 1. Recreate the .env asset from Vercel Environment Variables.
#    .env is gitignored (it holds secrets) so it is NOT in the checkout, but
#    the app bundles it as a Flutter asset and reads it at runtime via
#    flutter_dotenv. Set SUPABASE_URL / SUPABASE_ANON_KEY in the Vercel
#    dashboard (Project > Settings > Environment Variables).
# ---------------------------------------------------------------------------
cat > .env <<EOF
SUPABASE_URL=${SUPABASE_URL:-}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
EOF

# ---------------------------------------------------------------------------
# 2. Install Flutter (stable). Reused if Vercel's build cache keeps the dir.
# ---------------------------------------------------------------------------
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi
export PATH="$PWD/flutter/bin:$PATH"

# Mark the cloned SDK as a safe git directory (Vercel runs as a different user).
git config --global --add safe.directory "$PWD/flutter" || true

# ---------------------------------------------------------------------------
# 3. Build the web app. Vercel serves at the domain root, so base-href stays /.
# ---------------------------------------------------------------------------
flutter --version
flutter pub get
flutter build web --release
