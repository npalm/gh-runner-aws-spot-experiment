import { EC2 } from 'aws-sdk';
import { SSM } from 'aws-sdk';
import AWS from 'aws-sdk';

AWS.config.update({
    region: process.env.AWS_REGION
});
const ec2client = new EC2();
const ssm = new SSM();

const params: EC2.RunInstancesRequest = {
    InstanceType: process.env.RUNNER_INSTANE_TYPE,
    SubnetId: process.env.RUNNER_SUBNET_ID,
    MaxCount: 1,
    MinCount: 1,
    LaunchTemplate: {
        "LaunchTemplateName": process.env.RUNNER_LAUNCHTEMPLATE_NAME,
        "Version": process.env.RUNNER_LAUNCHTEMPLATE_VERSION
    },
}

async function tag(instanceIds: string[]) {
    console.log(instanceIds);
    await new Promise(r => setTimeout(r, 2000));
    const spotRequests = await ec2client.describeSpotInstanceRequests({
        Filters: [
            { Name: "instance-id", Values: instanceIds }
        ]
    }).promise();

    const spotrequestIds = <EC2.ResourceIdList>spotRequests.SpotInstanceRequests?.map((i) => <string>i.SpotInstanceRequestId)
    const tags = await ec2client.createTags({
        Resources: <EC2.ResourceIdList>instanceIds.concat(spotrequestIds),
        Tags: [
            { Key: "Name", Value: "runner" }
        ]
    }).promise();
}

async function creatInstance(token: string, repoUrl: string) {
    const response = await ec2client.runInstances(params).promise();
    const instancesIds = <string[]>response.Instances?.map((i) => <string>i.InstanceId)
    await tag(instancesIds);
    instancesIds.forEach(async (i) => {
        await ssm.putParameter({
            Name: "runner-token-" + i,
            Value: token,
            Type: "String"
        }).promise()
    });
    instancesIds.forEach(async (i) => {
        await ssm.putParameter({
            Name: "runner-repo-" + i,
            Value: repoUrl,
            Type: "String"
        }).promise()
    });
}


function getNumberOfInstances(reservations: EC2.ReservationList): number {
    return (<number[]>reservations.map(r => r.Instances?.length)).reduce((a, b) => a + b, 0)
}

export const createRunner = async (token: string, repoUrl: string) => {
    console.log("creating runner");
    const response = await ec2client.describeInstances({

        Filters: [{
            Name: "tag:Name",
            Values: ["runner"]
        },
        {
            Name: "instance-state-name",
            Values: ["running", "pending"]
        }]
    }).promise();
    const max: number = parseInt(process.env.RUNNER_ORCHESTRATION_MAX_INSTANCES as string);
    if (getNumberOfInstances(<EC2.ReservationList>response.Reservations) <= max) {
        console.log("create");
        await creatInstance(token, repoUrl);
    }

}
