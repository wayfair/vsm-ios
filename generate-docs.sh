#!/bin/bash
# This script is invoked by /.github/workflows/pages.yml
# It is kept separate so that it can be tested locally/manually
# The ./docs path is needed by /.github/workflows/pages.yml for deployment
swift package --allow-writing-to-directory ./docs \
    generate-documentation --target VSM \
    --output-path ./docs \
    --hosting-base-path vsm-ios \
    --transform-for-static-hosting \
    --disable-indexing
