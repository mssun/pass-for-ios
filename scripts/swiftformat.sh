SWIFTFORMAT_VERSION="0.48.*"

if [[ "${CI}" == "true" ]]; then
  echo "Running in a Continuous Integration environment. Formatting is skipped."
  exit 0 
fi

if [[ "${CONFIGURATION}" == "Release" ]]; then
  echo "Running during a release build. Formatting is skipped."
  exit 0
fi

if which swiftformat > /dev/null; then
  if [[ "$(swiftformat --version)" == $SWIFTFORMAT_VERSION ]]; then
    swiftformat .
  else
    echo "Failure: SwiftFormat $SWIFTFORMAT_VERSION is required. Install it or update the build script to use a newer version."
    exit 1
  fi
else
  echo "Failure: SwiftFormat not installed. Get it via 'brew install swiftformat'."
  exit 2
fi

