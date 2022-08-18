swift package --allow-writing-to-directory ./docs \
    generate-documentation --target VSM \
    --output-path ./docs \
    --hosting-base-path vsm-ios \
    --transform-for-static-hosting \
    --disable-indexing
