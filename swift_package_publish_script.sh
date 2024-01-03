#!/bin/bash

## pull variables from configuration file
source publish_configuration.sh

echo "$1"

## check input variable for if we should use curl or swift package-registry publish

CURL_URL="$ARTIFACT_URL""$PACKAGE_SCOPE""/""$PACKAGE_NAME""/""$PACKAGE_VERSION"

if [ ! -z "$1" ] && [ "$1" = "curl" ]
then 
    echo "we are using curl to publish"
    ## Setup

    rm -rf "$BUILD_FOLDER_PATH"
    mkdir "$BUILD_FOLDER_PATH"

    OUTPUT_FILE="$BUILD_FOLDER_PATH""/""$PACKAGE_NAME""-""$PACKAGE_VERSION"".zip"

    # echo "output file path: ""$OUTPUT_FILE"

    ## Create archive of build
    swift package archive-source --output="$OUTPUT_FILE"

    ## upload build using curl
    curl -X PUT --netrc                                      \
       -H \""Accept: application/vnd.swift.registry.v1+json"\" \
       -F source-archive=\""@""$OUTPUT_FILE"\"           \
       "$CURL_URL"

    # curl -X PUT --netrc \
    #  -H "Accept: application/vnd.swift.registry.v1+json" \
    #  -F source-archive="@<source_archive_path>"https://jkcompute.jfrog.io/artifactory/api/swift/swift/<scope>/<name>/<version>
else
    echo "we are using swift package-registry publish"

    # Publish command will build and send artifact to repo, this also sends the metadata
    # version 5.9+ of swfit is required to use this command
    # builds folder is outside of the project folder as we get a duplicate file error if it is inside the package.
    echo swift package-registry publish "$PACKAGE_SCOPE"."$PACKAGE_NAME" "$PACKAGE_VERSION" --registry-url "$ARTIFACT_URL"   --scratch-directory "$BUILD_FOLDER_PATH" --metadata-path "$METADATA_PATH_AND_FILE"

fi

## We do these steps via curl in all cases.  There is no swift-provided checksum upload api at this time. 

## Upload checksum to artifactory Using Curl
for file in $(find "$BUILD_FOLDER_PATH" -name "*.zip" -type f)
do
    # echo $file
  ## note: some systems use md5sum for MD5 checksum, i am using MacOS so md5 is used. 
    ARTIFACT_MD5_CHECKSUM=$(md5 -q $file | awk '{print $1}')
    ARTIFACT_SHA1_CHECKSUM=$(shasum -a 1 $file | awk '{ print $1 }')
    ARTIFACT_SHA256_CHECKSUM=$(shasum -a 256 $file | awk '{ print $1 }')

    curl --netrc \
            --header "X-Checksum-MD5:${ARTIFACT_MD5_CHECKSUM}" \
            --header "X-Checksum-Sha1:${ARTIFACT_SHA1_CHECKSUM}" \
            --header "X-Checksum-Sha256:${ARTIFACT_SHA256_CHECKSUM}" \
            -v "$CURL_URL"
done

## Clean up
#rm -rf "$BUILD_FOLDER_PATH"