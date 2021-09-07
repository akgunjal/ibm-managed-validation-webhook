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

set -e
set +x
git config --global url."https://$GHE_TOKEN@github.ibm.com/".insteadOf "https://github.ibm.com/"
set -x
cd /go/src/github.ibm.com/alchemy-containers/managed-storage-validation-webhooks
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=on go build -a -ldflags '-X main.storageValidationWebhooks='"storageValidationWebhooks-${TAG}"' -extldflags "-static"' -o /go/bin/managed-storage-validation-webhooks ./cmd/
