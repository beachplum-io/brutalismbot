user    := UH9M57X6Z
secret  := brutalismbot/beta
token   := $(shell aws secretsmanager get-secret-value --secret-id $(secret) | jq -r '.SecretString|fromjson|.SLACK_API_TOKEN')
auth    := authorization: Bearer $(token)
channel := $(shell curl -s -H "$(auth)" 'https://slack.com/api/conversations.open?users=$(user)' | jq -r '.channel.id')

logs:
	aws logs tail /aws/lambda/brutalismbot-api-slack-beta --follow \
	| grep --line-buffered EventBridge:PutEvents \
	| grep --line-buffered -o '{.*}' \
	| jq '.entries[]|{EventBusName:.event_bus_name, Source:.source, DetailType:.detail_type, Detail:(.detail|fromjson)}'

clear:
	curl -s -H "$(auth)" 'https://slack.com/api/conversations.history?channel=$(channel)' \
	| jq -r '.messages[].ts' \
	| sort \
	| xargs -n1 printf 'https://slack.com/api/chat.delete?channel=$(channel)&ts=%s\n' \
	| xargs -n1 curl -s -H "$(auth)"
