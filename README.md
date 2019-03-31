<img alt="brutalismbot" src="./docs/banner.png"/>

A Slack app that mirrors posts from
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

<img alt="post" src="./docs/post.png" width="500"/>
