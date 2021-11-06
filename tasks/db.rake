namespace :db do
  namespace :list do
    namespace :slack do
      desc 'List SLACK/AUTH items'
      task :auths do
        sh <<~SH
          echo
          aws dynamodb query \
          --table-name Brutalismbot \
          --index-name Chrono \
          --key-condition-expression '#SORT = :SORT' \
          --expression-attribute-names '{"#SORT":"SORT"}' \
          --expression-attribute-values '{":SORT":{"S":"SLACK/AUTH"}}' \
          | jq -r '.Items[] | .TEAM_NAME.S+"|"+.CHANNEL_NAME.S+"|"+.GUID.S' \
          | sort \
          | column -t -s '|'
          echo
        SH
      end
    end
  end
end
