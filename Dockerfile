# Build the manager binary
FROM golang:1.16.7 as build

RUN mkdir -p /workdir
WORKDIR /workdir
COPY . .

# Build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=on go build -o managed-storage-validation-webhooks cmd/main.go

ARG PROXY_IMAGE_URL
FROM wcp-alchemy-containers-team-icr-docker-remote.artifactory.swg-devops.com/armada-master/ibm-storage-ubi8:8.4-208

# Default values
ARG git_commit_id=unknown
ARG git_remote_url=unknown
ARG build_date=unknown
ARG travis_build_number=unknown
ARG REPO_SOURCE_URL=blank
ARG BUILD_URL=blank
ARG TAG
ARG OS
ARG ARCH

# Add Labels to image to show build details
LABEL git-commit-id=${git_commit_id}
LABEL git-remote-url=${git_remote_url}
LABEL build-date=${build_date}
LABEL travis_build_number=${travis_build_number}
LABEL razee.io/source-url="${REPO_SOURCE_URL}"
LABEL razee.io/build-url="${BUILD_URL}"

WORKDIR /
COPY --from=build /workdir/managed-storage-validation-webhooks /usr/local/bin/
ADD build/bin/* /usr/local/bin/

ENV USER_UID=1000 \
  USER_NAME=managed-storage-validation-webhooks
RUN /usr/local/bin/user_setup

USER ${USER_UID}

ENTRYPOINT [ "/usr/local/bin/entrypoint" ]
