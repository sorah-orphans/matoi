require 'groonga'
require 'time'

module Matoi
  class Tweet
    class << self
      def add(tweet)
        users    = Groonga['users']
        tweets   = Groonga['tweets']
        urls     = Groonga['urls']
        hashtags = Groonga['hashtags']
        yms      = Groonga['year_months']
        ymds     = Groonga['year_month_days']

        attrs = {}

        if tweet['retweeted_status']
          retweeter = self.user_by_attrs(tweet['user'])
          if tweets[tweet['retweeted_status']['id']]
            record = tweets[tweet['retweeted_status']['id']]
            return tweets.add(tweet['retweeted_status']['id'], retweeted_users: record.retweeted_users + [retweeter])
          else
            attrs[:retweeted_users] = [retweeter]
            tweet = tweet['retweeted_status']
          end
        end

        user = attrs[:user] = self.user_by_attrs(tweet['user'])
        attrs[:text] = tweet['text']

        if tweet['in_reply_to_status_id']
          attrs[:in_reply_to_status_id] = in_reply_to = tweet['in_reply_to_status_id']
          attrs[:in_reply_to] = tweets[in_reply_to]
        end

        created_at = attrs[:created_at] = Time.parse(tweet['created_at'])
        attrs[:day] = created_at.day
        attrs[:hour] = created_at.hour
        attrs[:year_month] = yms.add(created_at.strftime('%Y/%m'))
        attrs[:year_month_day] = ymds.add(created_at.strftime('%Y/%m/%d'))

        attrs[:source] = tweet['source'].gsub(/<.+?>/, '')

        attrs[:hashtags] = tweet['entities']['hashtags'].map { |t| hashtags.add(t['text']) }
        attrs[:mentioned_users] = tweet['entities']['user_mentions'].map do |u|
          self.user_by_attrs('id' => u['id'], 'screen_name' => u['screen_name'])
        end
        attrs[:urls] = tweet['entities']['urls'].map do |u|
          urls.add(u['expanded_url'], url: u['url'], display_url: u['display_url'])
        end

        tweets.add(tweet['id'], attrs)
      end

      def user_by_attrs(user)
        Groonga['users'].add(user['id'], {
          screen_name:             user['screen_name'],
          profile_image_url:       user['profile_image_url'],
          profile_image_url_https: user['profile_image_url_https']
        })
      end
    end
  end
end
