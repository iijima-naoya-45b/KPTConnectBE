# Use this file to easily define all of your cron jobs.
#
# Learn more: http://github.com/javan/whenever

# 毎日朝9時にKPTリマインダーを送信（朝のモチベーション向上）
every 1.day, at: "9:00 am" do
  runner "DailyKptReminderJob.perform_later"
end

# 毎日夕方18時にKPTリマインダーを送信（1日の振り返り促進）
every 1.day, at: "6:00 pm" do
  runner "DailyKptReminderJob.perform_later"
end

# 開発環境での動作確認用（コメントアウト）
# every 1.minute do
#   runner "DailyKptReminderJob.perform_later"
# end
