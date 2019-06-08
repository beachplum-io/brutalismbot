<img alt="brutalismbot" src="https://brutalismbot.com/banner.png"/>

A [Slack app](https://slack.com/apps/AH0KW28C9-brutalismbot) that mirrors posts from
[/r/brutalism](https://www.reddit.com/r/brutalism/new)
to a #channel of your choosing using
[incoming webhooks](https://api.slack.com/incoming-webhooks).

<a href="https://www.brutalismbot.com/">
  <img alt="Add to Slack" height="40" width="139" src="https://platform.slack-edge.com/img/add_to_slack.png" srcset="https://platform.slack-edge.com/img/add_to_slack.png 1x, https://platform.slack-edge.com/img/add_to_slack@2x.png 2x" />
</a>

## How It Works

After granting Brutalismbot permission to post to a #channel on your Slack workspace, Brutalismbot will save a copy of the incoming webhook URL to which it will publish posts.

Every hour Brutalismbot requests posts from reddit's REST API at [`/r/brutalism/new.json`](https://reddit.com/r/brutalism/new).

New image posts that haven't been seen before are saved, transformed into Slack messages using [Block Kit](https://api.slack.com/block-kit), and published to your #channel via the incoming webhook URL.

Example post:

<img alt="post" src="https://brutalismbot.com/post.png" width="500"/>

## Architecture

The app consists of 3 parts: install/uninstall, caching new posts, and mirroring posts to installed workspaces.

### Install/Uninstall

<img alt="install-uninstall" src="https://brutalismbot.com/arch-install-uninstall.png"/>

When the app is installed, The Brutalismbot REST API sends a `POST` request to Slack's [oauth.access](https://api.slack.com/methods/oauth.access) REST endpoint. The resulting OAuth payload (with incoming webhook URL) is published to an SNS topic that triggers a Lambda that persists the payload to S3 and sends the current top bost on /r/brutalism to the new workspace using the webhook URL.

When the app is uninstalled, Slack sends a `POST` request of the uninstall event to the Brutalismbot REST API. The event is published to an SNS topic that triggers a Lambda to remove the OAuth from S3.

### Cache

<img alt="cache" src="https://brutalismbot.com/arch-cache.png" width="500"/>

Every hour (ish) a CloudWatch event triggers a Lambda to get new posts from the /r/brutalism REST API and persists the JSON representation of the post to S3.

### Mirror

<img alt="mirror" src="https://brutalismbot.com/arch-mirror.png" width="500"/>

When a new post is persisted to S3, an S3 bucket notification triggers a Lambda to convert the post to a Slack message and post to every installed workspace.

### See Also

- [Brutalismbot API](https://github.com/brutalismbot/api)
- [Brutalismbot Gem](https://github.com/brutalismbot/gem)
- [Brutalismbot Monitoring](https://github.com/brutalismbot/monitoring)
