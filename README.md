# GitHub action self-hosted runner on AWS spot (experiment)

> Be-aware this repo is experimental.

Repo contains a setup to scale runners in an GitHub organization based on demands. Once a new build is queued the orchestrator will create based on set maximums a new instance in AWS. 

## Components

### Terraform infrastructure
The terraform project will create a VPC, security groups and a launch template for the runner. Terraform apply will print the required data for the orchestrator.

### Orchestrator

The orchestrator can run locally via `express` or on AWS as Lambda function and expose the the web hook via the API gateway. The orchestrator will require a GitHub app to get access to the GitHub API.

The orchestrator will listen for events of a GitHub app, once received it verifies the the request based ont on the secret. For a valid request of the type `check_run` and status `queued` it will wait another seconds and re-check the status is still `queued`. If yes, a new AWS spot instances is created with a gh-runner. You can set a max of running instances.

Down scaling not implemented yet!

## Setup

### Create infra
Requires:
- AWS credentials
- tfenv or Terraform 0.12.x installed

```
cd terraform/examples/default
terraform init
terraform apply # check the change set and accept.
```
Please keep the terraform outputs for the template name, template version and subnet.

### Create GitHub App
Go to https://github.com/settings/apps/ and crate a new GitHub app
- Fill: name / homepage
- Permissions: read/write on Repo level actions and administration
- Disable webhook for now
- Save and next generate a key pair


### Create orchestrator
```
cd orchestrator
yarn
```
next set the following environment variables
```bash
GITHUB_APP_CLIENT_ID=<see app page>
GITHUB_APP_ID=<see app page>
GITHUB_APP_CLIENT_SECRET=<see app page>
GITHUB_APP_KEY=$(cat key.pem)
RUNNER_SUBNET_ID=<see terraform output>
RUNNER_INSTANE_TYPE="m4.large"
RUNNER_LAUNCHTEMPLATE_NAME=see terraform output>
RUNNER_LAUNCHTEMPLATE_VERSION=see terraform output>
RUNNER_ORCHESTRATION_WAIT_FOR_SCALE=5
RUNNER_ORCHESTRATION_MAX_INSTANCES=2
GITHUB_APP_WEBHOOK_SECRET=<your secret for the webook>
```
Next you need a option to route the webhook traffic, unless you would like to expose your dev environment directly to the web. A good option can be https://smee.io/. Once you have you webhook listener running (e.g. smee.io), you can configure the web hook and secret of you app. Go back to you app settings in GitHub and configure the webhook and secret.

Now you should be ready to start the `express server`
```
yarn start
```

Alternative you can crate a Lambda in AWS. Build the lambda distribution.
```
yarn build 
  && cd build \
  && cp ../package.json . \
  && yarn --production \
  && zip -r  ../dist.zip . \
  && ce ..
```
Next:
- Copy dist.zip to S3
- Create a lambda
  - Ensure you increase the execution time to 1 minute or so.
  - Ensure you set the configuration variables
  - entry point is `lambda/githubWebhook`
  - connect the lambda to the API gateway.
  - Update the GItHub app with the API gateway endpoint.

### Test

Finally it is time to test. Install the the new app for a test repo and push a change. Of course ensure you have a workflow for a self-hosted runner.