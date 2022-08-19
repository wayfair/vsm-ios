# This script is invoked by /.github/workflows/pages.yml
# It is kept separate so that it can be tested locally/manually
swift package --allow-writing-to-directory ./docs \
    generate-documentation --target VSM \
    --output-path ./docs \ # This path is coordinated with /.github/workflows/pages.yml
    --hosting-base-path vsm-ios \
    --transform-for-static-hosting \
    --disable-indexing
