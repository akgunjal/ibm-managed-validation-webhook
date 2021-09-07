#!/bin/bash
# /*******************************************************************************
# * IBM Confidential
# * OCO Source Materials
# * IBM Cloud Container Service, 5737-D43
# * (C) Copyright IBM Corp. 2021 All Rights Reserved.
# * The source code for this program is not  published or otherwise divested of
# * its trade secrets, irrespective of what has been deposited with
# * the U.S. Copyright Office.
# ******************************************************************************/

if [ "$TRAVIS_PULL_REQUEST" != "false" ] && [ "$TRAVIS_GO_VERSION" == "tip" ]; then
	curl -s -k -X GET -H "Content-Type: application/json" -H "Accept: application/vnd.travis-ci.2+json"  -H "Authorization: token $TRAVIS_TOKEN"  https://travis.ibm.com/alchemy-containers/managed-storage-validation-webhooks/builds/$TRAVIS_BUILD_ID | jq '.jobs[0].state' | sed 's/"//g'> state.out
	RESULT=$(<state.out)
	if [ "$RESULT" != "failed" ]; then
		RESULT_MESSAGE=":warning: Build failed with **tip** version."
		curl -X POST -H "Authorization: token $GHE_TOKEN" https://github.ibm.com//alchemy-containers/managed-storage-validation-webhooks/repos/$TRAVIS_REPO_SLUG/issues/$TRAVIS_PULL_REQUEST/comments -H 'Content-Type: application/json' --data '{"body": "'"$RESULT_MESSAGE"'"}'
	fi
fi
