ECR_ACCOUNT=421650114650
ECR_REGION=ap-southeast-2
ECR_URL=${ECR_ACCOUNT}.dkr.ecr.ap-southeast-2.amazonaws.com

IMAGE_NAME=sample_compute
IMAGE_NAME_DEV=${IMAGE_NAME}_dev

SEMVER_MAJOR:=$(shell cut -d . -f 1 version) # 0
SEMVER_MINOR:=$(shell cut -d . -f 2 version) # 0
SEMVER_PATCH:=$(shell cut -d . -f 3 version) # 1

GIT_COMMIT=$(shell git rev-parse --short HEAD) # a1b2c3

DEV_VERSION=${SEMVER_MAJOR}.${SEMVER_MINOR}.${SEMVER_PATCH}-${GIT_COMMIT} # 0.0.1-a1b2c3
RELEASE_VERSION=${SEMVER_MAJOR}.${SEMVER_MINOR}.${SEMVER_PATCH} #0.0.1

DEV_TAG=${ECR_URL}/${IMAGE_NAME_DEV}:${DEV_VERSION} # 123456789.dkr.ecr.ap-southeast-2.amazonaws.com/sample_computer_dev:0.0.1-a1b2c3
RELEASE_TAG=${ECR_URL}/${IMAGE_NAME_DEV}:${RELEASE_VERSION} # 123456789.dkr.ecr.ap-southeast-2.amazonaws.com/sample_computer_dev:0.0.1

MIN_COVERAGE=80

.DEFAULT_GOAL := help

help:
	@echo "Build targets:"
	@echo "- build-dev:                             builds docker dev images for the pylon demo"
	@echo "- unit-test-dev:                         Runs unit tests on the dev docker image"
	@echo "- publish-dev:                           publishes docker images to the pylon demo dev ECR"
	@echo "- publish-release:                       publishes docker iamges to the pylon demo ECR"
	@echo "- deploy-dev:                            deploys the pylon demo application in dev"
	@echo "- WORKSPACE=<workspace> deploy-release:  deploys the pylon demo application in <workspace>"
	@echo "- WORKSPACE=<workspace> destroy: tears down the application and all infrastructure in <workspace>"

git-status-check:
	# fail if there are changes which have not been commited
	@if git diff --quiet HEAD --;\
	then\
		echo "Git status check passed. Beginning build";\
    else\
		echo "[ERROR] Uncommitted changes detected, build aborted";\
		false;\
    fi

env-file-dev: git-status-check
    # populating .env
	@rm -f .env
	@echo "IMAGE_NAME=${IMAGE_NAME_DEV}" >> .env
	@echo "ECR_URL=${ECR_URL}" >> .env
	@echo "MAJOR=${SEMVER_MAJOR}" >> .env
	@echo "MINOR=${SEMVER_MINOR}" >> .env
	@echo "PATCH=${SEMVER_PATCH}" >> .env
	@echo "GIT_COMMIT=${GIT_COMMIT}" >> .env
	cat .env

env-file: git-status-check
    # populating .env
	@rm -f .env
	@echo "IMAGE_NAME=${IMAGE_NAME}" >> .env
	@echo "ECR_URL=${ECR_URL}" >> .env
	@echo "MAJOR=${SEMVER_MAJOR}" >> .env
	@echo "MINOR=${SEMVER_MINOR}" >> .env
	@echo "PATCH=${SEMVER_PATCH}" >> .env
	@echo "GIT_COMMIT=${GIT_COMMIT}" >> .env
	cat .env

ecr-login:
	`aws ecr get-login --registry-ids ${ECR_ACCOUNT} --region ${ECR_REGION} --no-include-email`

build-local-dev: ecr-login
	docker-compose build ecr_release && \
	cd tests/ && \
	IMAGE_NAME=${IMAGE_NAME}_dev ECR_URL=${ECR_URL} MAJOR=${SEMVER_MAJOR} MINOR=${SEMVER_MINOR} PATCH=${SEMVER_PATCH} \
	docker-compose -f docker-compose-local-test.yaml up

build-dev: env-file-dev ecr-login
	# builds an image with the postfixed by _dev to mark it as a dev image
	docker build --tag ${DEV_TAG} .

build-release: env-file-dev ecr-login
	# builds an image with the postfixed by _dev to mark it as a dev image
	docker build --tag ${RELEASE_TAG} .

create-output-dir:
	# creates an output directory for test results to go into
	# we need this because if docker creates it, the owner is root
	# and jenkins can't delete the directory when cleaning up
	mkdir -p tests/unit/.outputs

unit-test-dev: create-output-dir
	# run unit tests on the dev image
	# relies on the dev image being created before
	cd tests/unit && \
	BASE_IMAGE=${DEV_TAG} \
	docker-compose build && \
	MIN_COVERAGE=${MIN_COVERAGE} docker-compose run send-adapter-test

unit-test-release: create-output-dir
	# run unit tests on the dev image
	# relies on the dev image being created before
	cd tests/unit && \
	BASE_IMAGE=${RELEASE_TAG} \
	docker-compose build && \
	MIN_COVERAGE=${MIN_COVERAGE} docker-compose run send-adapter-test

publish-dev: ecr-login
	# pushes the dev image to the dev ECR
	docker push ${DEV_TAG}

publish-release: ecr-login
	# pull the prerelease, retag as a release and then push the image
	# this allows us to release the same artifact that was tested
	# also create a git tag to mark the release
	docker push ${RELEASE_TAG} && \
	git tag ${RELEASE_VERSION} -m 'Release ${RELEASE_VERSION}' && \
	git push --tags

deploy-dev:
	# apply the terraform in the dev account with the dev image
	cd terraform && \
	terraform init -no-color && \
	(terraform workspace select dev -no-color || terraform workspace new dev -no-color) && \
	terraform get --update -no-color && \
	terraform plan \
	-var 'image_name=${IMAGE_NAME_DEV}' \
	-var 'image_version=${DEV_VERSION}' \
	-input=false -out=tfplan -no-color && \
	terraform apply -input=false -no-color tfplan

deploy-release:
	# apply the terraform in stage or prod with the release image
	cd terraform && \
	terraform init -no-color && \
	(terraform workspace select dev -no-color || terraform workspace new dev -no-color) && \
	terraform get --update -no-color && \
	terraform plan \
	-var 'image_name=${IMAGE_NAME}' \
	-var 'image_version=${RELEASE_VERSION}' \
	-input=false -out=tfplan -no-color && \
	terraform apply -input=false -no-color tfplan

destroy:
	# destroy all things pylon demo related in the specified account
	# e.g. `WORKSPACE=dev make destroy` destroys in the dev account
	# terraform requires the variables, but they don't seem to change the behaviour
	cd terraform && \
	terraform init -no-color && \
	terraform workspace select -no-color ${WORKSPACE} && \
	terraform plan \
	-var 'image_name=${IMAGE_NAME}' \
	-var 'image_version=${RELEASE_VERSION}' \
	-destroy -input=false -no-color && \
	terraform destroy \
	-var 'image_name=${IMAGE_NAME}' \
	-var 'image_version=${RELEASE_VERSION}' \
	-input=false -auto-approve -no-color

make clean:
	rm -f .env tfplan

.PHONY := git-status-check env-file ecr-login create-output-dir deploy-dev deploy-pre-release deploy-release destroy