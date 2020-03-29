import express from 'express';
import { IncomingHttpHeaders } from 'http';
import crypto from 'crypto';
import { Octokit } from "@octokit/rest";
import { createRunner } from '../instance';
import { createAppAuth } from "@octokit/auth-app";

function signRequestBody(key: string, body: any) {
    return `sha1=${crypto.createHmac('sha1', key).update(body, 'utf8').digest('hex')}`;
}

var githubClient: Octokit;

async function createGithubClient(installationId: number) {
    const privateKey = process.env.GITHUB_APP_KEY as string;
    const appId: number = parseInt(process.env.GITHUB_APP_ID as string)
    const clientId = process.env.GITHUB_APP_CLIENT_ID as string;
    const clientSecret = process.env.GITHUB_APP_CLIENT_SECRET as string;

    try {
        const auth = createAppAuth({
            id: appId,
            privateKey: privateKey,
            installationId: installationId,
            clientId: clientId,
            clientSecret: clientSecret
        });
        const appAuthentication = await auth({ type: "app" });
        const installationAuthentication = await auth({ type: "installation" });

        githubClient = new Octokit({
            auth: installationAuthentication.token
        })

    } catch (e) {
        console.log(e);
    }

}

function sleep(seconds: number) {
    return new Promise(resolve => setTimeout(resolve, seconds * 1000));
}

export const handle = async (headers: IncomingHttpHeaders, payload: any): Promise<number> => {
    const token = process.env.GITHUB_APP_WEBHOOK_SECRET as string;
    const sig = headers['x-hub-signature'];
    const githubEvent = headers['x-github-event'];
    const id = headers['x-github-delivery'];
    const calculatedSig = signRequestBody(token, payload);

    if (sig !== calculatedSig) {
        console.log("signature invalid.")
        return 401;
    }

    const body = JSON.parse(payload);

    console.log('---------------------------------');
    console.log(`Github-Event: "${githubEvent}" with action: "${body.action}"`);
    console.log('---------------------------------');

    if (githubEvent === 'check_run' && body.action === 'created' && body.check_run.status === 'queued') {
        console.log('status', body.check_run.status);
        console.log('name', body.repository.name);
        console.log('owner', body.repository.owner.login);

        await createGithubClient(body.installation.id);
        const token = await githubClient.actions.createRegistrationToken({
            repo: body.repository.name,
            owner: body.repository.owner.login
        })
        try {
            console.log("sleep");
            const wait: number = parseInt(process.env.RUNNER_ORCHESTRATION_WAIT_FOR_SCALE as string);

            sleep(wait).then(async () => {
                try {
                    const status = (await githubClient.checks.get({
                        owner: body.repository.owner.login,
                        repo: body.repository.name,
                        check_run_id: body.check_run.id
                    })).data.status;

                    if (status === 'queued') {
                        console.log("Request a new runner");
                        await createRunner(token.data.token, "https://github.com/" + body.repository.owner.login + "/" + body.repository.name);
                    } else {
                        console.log("No new runner requested for status: " + status);
                    }
                } catch (e) {
                    console.log(e);
                }
            })
        } catch (e) {
            console.log(e);
        }

    } else {
        console.log("ignore event " + githubEvent);
    }

    return 200;
}
