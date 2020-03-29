#!/bin/bash -e
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

if [[ $(echo false) == false ]]; then
    set -x
fi

# Add current hostname to hosts file
tee /etc/hosts <<EOL
127.0.0.1   localhost localhost.localdomain $(hostname)
EOL

for i in {1..7}; do
    echo "Attempt: ---- " $i
    yum -y update && break || sleep 60
done

echo 'installing additional software for logging'
# installing in a loop to ensure the cli is installed.
for i in {1..7}; do
    echo "Attempt: ---- " $i
    yum install -y aws-cli awslogs jq && break || sleep 60
done

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

# Inject the CloudWatch Logs configuration file contents
cat >/etc/awslogs/awslogs.conf <<-EOF
[general]
state_file = /var/lib/awslogs/agent-state

[/var/log/dmesg]
file = /var/log/dmesg
log_stream_name = {instanceId}/dmesg
log_group_name = niek-play
initial_position = start_of_file

[/var/log/messages]
file = /var/log/messages
log_stream_name = {instanceId}/messages
log_group_name = niek-play
datetime_format = %b %d %H:%M:%S
initial_position = start_of_file

[/var/log/user-data.log]
file = /var/log/user-data.log
log_stream_name = {instanceId}/user-data
log_group_name = niek-play
initial_position = start_of_file

EOF

# Set the region to send CloudWatch Logs data to (the region where the instance is located)
region=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

sed -i -e "s/region = us-east-1/region = $region/g" /etc/awslogs/awscli.conf

# Replace instance id.
instanceId=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)
sed -i -e "s/{instanceId}/$instanceId/g" /etc/awslogs/awslogs.conf

service awslogsd start
chkconfig awslogsd on

yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm

yum install jq git -y

mkdir actions-runner && cd actions-runner
curl -O -L https://github.com/actions/runner/releases/download/v2.165.2/actions-runner-linux-x64-2.165.2.tar.gz
tar xzf ./actions-runner-linux-x64-2.165.2.tar.gz
rm -rf actions-runner-linux-x64-2.165.2.tar.gz
export RUNNER_ALLOW_RUNASROOT=1

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
