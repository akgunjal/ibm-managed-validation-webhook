WEBHOOK_EXE_NAME=managed-storage-validation-webhooks
WEBHOOK_NAME=storageValidationWebhooks

IMAGE = obs/${WEBHOOK_EXE_NAME}

GOPACKAGES=$(shell go list ./... | grep -v /vendor/ | grep -v /cmd | grep -v /tests)
PROXY_IMAGE_URL:="registry.ng.bluemix.net"

ifndef TRAVIS_COMMIT
TRAVIS_COMMIT=dev
endif

ifdef ARTIFACTORY_API_KEY
GOPROXY := https://${ARTIFACTORY_USER}:${ARTIFACTORY_API_KEY}@na.artifactory.swg-devops.com/artifactory/api/go/wcp-alchemy-containers-team-go-virtual
GONOPROXY := github.ibm.com
PROXY_IMAGE_URL="wcp-alchemy-containers-team-icr-docker-remote.artifactory.swg-devops.com"
endif

GIT_COMMIT_SHA="$(shell git rev-parse HEAD 2>/dev/null)"
GIT_REMOTE_URL="$(shell git config --get remote.origin.url 2>/dev/null)"
BUILD_DATE="$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")"
ARCH=$(shell docker version -f {{.Client.Arch}})
OSS_FILES := go.mod Dockerfile

# Jenkins vars. Set to `unknown` if the variable is not yet defined
BUILD_NUMBER?=unknown
GO111MODULE_FLAG?=on
export GO111MODULE=$(GO111MODULE_FLAG)

# disable referring packages from sum.golang.org
export GOSUMDB=off
export LINT_VERSION="1.27.0"

COLOR_YELLOW=\033[0;33m
COLOR_RESET=\033[0m

.PHONY: all
all: deps fmt build test buildimage

.PHONY: webhooks
webhooks: deps gosec buildimage

.PHONY: deps
deps:
	echo "Installing dependencies ..."
	#glide install --strip-vendor
	go mod download
	go get github.com/pierrre/gotestcover
	@if ! which golangci-lint >/dev/null || [[ "$$(golangci-lint --version)" != *${LINT_VERSION}* ]]; then \
		curl -sfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(shell go env GOPATH)/bin v${LINT_VERSION}; \
	fi

.PHONY: fmt
fmt: lint
	golangci-lint run --disable-all --enable=gofmt --timeout 600s
	@if [ -n "$$(golangci-lint run)" ]; then echo 'Please run ${COLOR_YELLOW}make dofmt${COLOR_RESET} on your code.' && exit 1; fi

.PHONY: oss
oss:
	go run github.ibm.com/alchemy-containers/armada-opensource-lib/cmd/makeoss ${OSS_FILES}
	go mod tidy
	sed -i '/armada-opensource-lib/d' ./OPENSOURCE

.PHONY: dofmt
dofmt:
	golangci-lint run --disable-all --enable=gofmt --fix --timeout 600s

.PHONY: lint
lint:
	golangci-lint run --timeout 600s

.PHONY: build
build:
	CGO_ENABLED=0 GOOS=$(shell go env GOOS) GOARCH=$(shell go env GOARCH) go build -mod=vendor -a -ldflags '-X main.storageValidationWebhooks='"${WEBHOOK_NAME}-${GIT_COMMIT_SHA}"' -extldflags "-static"' -o ${GOPATH}/bin/${WEBHOOK_EXE_NAME} ./cmd/

.PHONY: buildsa
buildsa:
	CGO_ENABLED=0 GOOS=$(shell go env GOOS) GOARCH=$(shell go env GOARCH) go build -mod=vendor -a -ldflags '-X main.storageValidationWebhooks='"${WEBHOOK_NAME}-${GIT_COMMIT_SHA}"' -extldflags "-static"' -o sampleExe ./samples/

.PHONY: test-coverage
test-coverage:
	$(GOPATH)/bin/gotestcover -v -race -short -coverprofile=cover.out ${GOPACKAGES}
	go tool cover -html=cover.out -o=cover.html  # Uncomment this line when UT in place.

.PHONY: test
test: deps fmt test-coverage

.PHONY: buildimage
buildimage: #build-systemutil
	docker build	\
        --build-arg git_commit_id=${GIT_COMMIT_SHA} \
        --build-arg git_remote_url=${GIT_REMOTE_URL} \
        --build-arg build_date=${BUILD_DATE} \
        --build-arg travis_build_number=${TRAVIS_BUILD_NUMBER} \
		--build-arg REPO_SOURCE_URL=${REPO_SOURCE_URL} \
        --build-arg BUILD_URL=${BUILD_URL} \
        --build-arg PROXY_IMAGE_URL=${PROXY_IMAGE_URL} \
				--build-arg OS=linux \
				--build-arg ARCH=$(ARCH) \
				--build-arg TAG=$(GIT_COMMIT_SHA) \
	-t $(IMAGE):$(TRAVIS_COMMIT) -f Dockerfile .

#.PHONY: build-systemutil
#build-systemutil:
#	docker build --build-arg TAG=$(GIT_COMMIT_SHA) --build-arg OS=linux --build-arg ARCH=$(ARCH) -t storage-webhooks-builder --pull -f Dockerfile.builder .
	#docker run --env GHE_TOKEN=${GHE_TOKEN} storage-webhooks-builder
#	docker cp `docker ps -q -n=1`:/go/bin/${WEBHOOK_EXE_NAME} ./${WEBHOOK_EXE_NAME}

.PHONY: clean
clean:
	rm -rf ${WEBHOOK_EXE_NAME}
	rm -rf $(GOPATH)/bin/${WEBHOOK_EXE_NAME}

.PHONY: runanalyzedeps
runanalyzedeps:
	@docker build --rm --build-arg ARTIFACTORY_API_KEY="${ARTIFACTORY_API_KEY}"  -t armada/analyze-deps -f Dockerfile.dependencycheck .
	docker run -v `pwd`/dependency-check:/results armada/analyze-deps

.PHONY: analyzedeps
analyzedeps:
	/tmp/dependency-check/bin/dependency-check.sh --enableExperimental --log /results/logfile --out /results --disableAssembly \
		--suppress /src/dependency-check/suppression-file.xml --format JSON --prettyPrint --failOnCVSS 0 --scan /src

.PHONY: showanalyzedeps
showanalyzedeps:
	grep "VULNERABILITY FOUND" dependency-check/logfile;
	cat dependency-check/dependency-check-report.json |jq '.dependencies[] | select(.vulnerabilities | length>0)';

.PHONY: gosec
gosec:
	@if [ ! -f "$(GOPATH)/bin/gosec" ]; then curl -sfL https://raw.githubusercontent.com/securego/gosec/master/install.sh | sh -s -- -b ${GOPATH}/bin latest; fi
	$(GOPATH)/bin/gosec -exclude=G204 ./...
