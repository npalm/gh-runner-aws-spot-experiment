${pre_install}

echo "Installing docker"
if grep -q ':2$' /etc/system-release-cpe; then
    # AWS Linux 2 provides docker via extras only and uses systemd (https://aws.amazon.com/amazon-linux-2/release-notes/)
    amazon-linux-extras install docker
    usermod -a -G docker ec2-user
    systemctl enable docker
    systemctl start docker
else
    yum install docker -y
    usermod -a -G docker ec2-user
    service docker start
fi

yum install jq git -y


mkdir actions-runner && cd actions-runner
curl -O -L https://github.com/actions/runner/releases/download/v2.165.2/actions-runner-linux-x64-2.165.2.tar.gz
tar xzf ./actions-runner-linux-x64-2.165.2.tar.gz
rm -rf actions-runner-linux-x64-2.165.2.tar.gz
export RUNNER_ALLOW_RUNASROOT=1

region=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
instanceId=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)

echo wait for configuration
while [[ $(aws ssm get-parameters --names runner-token-$instanceId --with-decryption --region $region | jq -r ".Parameters | .[0] | .Value") == null ]]; do
    echo Waiting for token ...
done
token=$(aws ssm get-parameters --names runner-token-$instanceId --with-decryption --region $region | jq -r ".Parameters | .[0] | .Value")
while [[ $(aws ssm get-parameters --names runner-repo-$instanceId --with-decryption --region $region | jq -r ".Parameters | .[0] | .Value") == null ]]; do
    echo Waiting for token ...
done
repo=$(aws ssm get-parameters --names runner-repo-$instanceId --with-decryption --region $region | jq -r ".Parameters | .[0] | .Value")

./config.sh --url $repo --token $token --name "aws-runner" --work "_work"
./svc.sh install root
./svc.sh start
