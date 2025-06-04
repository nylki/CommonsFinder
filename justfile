lint:
    @echo 'linting...'
    swift format lint --configuration .swift-format --recursive --ignore-unparsable-files $("CommonsFinder/")
    @echo 'linting finished.'

format:
    @echo "formatting..."
    swift format --configuration .swift-format --recursive --ignore-unparsable-files --in-place "CommonsFinder/"
    @echo "formatting finished."