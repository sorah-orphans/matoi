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

        return nil unless tweet['user'] && tweet['text']

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

      def query(q)
        q = Sewell.generate(q, %w[text])

        dates, m_dates = [], []
        q.gsub!(/(\+ )?\(\s(-?)at:@(.+?)\s\)/) do
          ds = $2.empty? ? dates : m_dates
          at_str = $3
          if at_str =~ /^(\d+)\.\.(\d+)$/
            b_str, e_str = $1, $2
            b, e = Time.strptime(b_str, '%Y%m%d'), Time.strptime(e_str, '%Y%m%d')

            t = b
            while t <= e
              ds << t
              t += 86400
            end
          else
            ds << Time.strptime(at_str, '%Y%m%d')
          end
          ''
        end

        users = []
        m_users = []
        mentioned_users = []
        m_mentioned_users = []
        froms = []
        m_froms = []

        {'user' => [users, m_users], 'from' => [froms, m_froms],
         'mention' => [mentioned_users, m_mentioned_users],}.each do |k, (plus, minus)|
          q.gsub!(/\s-#{k}:@(.+?)\s/) do
            minus << $1.split(/,/)
            ''
          end
          q.gsub!(/\s#{k}:@(.+?)\s/) do
            plus << $1.split(/,/)
            ''
          end
        end

        [users, m_users, mentioned_users, froms, m_mentioned_users, m_froms].each do |us|
          us.flatten!
          us.map! do |u|
            user = Groonga['users'].select("screen_name:#{u}").first
            user ? user.key.key : u
          end
        end

        {users => '+', m_users => '-'}.each do |us, prefix|
          sub_query = us.map { |user_id|
            "user:#{user_id} OR mentioned_users:#{user_id}"
          }.join(' OR ')
          q << "#{prefix} ( #{sub_query} )" unless sub_query.empty?
        end

        {froms => '+', m_froms => '-'}.each do |us, prefix|
          sub_query = us.map { |user_id| "user:#{user_id}" }.join(' OR ')
          q << "#{prefix} ( #{sub_query} )" unless sub_query.empty?
        end

        {mentioned_users => '+', m_mentioned_users => '-'}.each do |us, prefix|
          sub_query = us.map { |user_id| "mentioned_users:#{user_id}" }.join(' OR ')
          q << "#{prefix} ( #{sub_query} )" unless sub_query.empty?
        end

        {dates => '+', m_dates => '-'}.each do |ds, prefix|
          next if ds.empty?

          sub_query = ds.map { |d| "year_month_day:#{d.strftime('%Y/%m/%d')}" }.join(" OR ")
          q << "#{prefix} ( #{sub_query} )"
        end



        q.gsub!(/\(\s*\)/, '')
        q.gsub!(/([\+\-]\s*)+([\+\-])/, '\2')
        q.gsub!(/^\s*\+\s*/, '')
        q.gsub!(/\)\s*([\+\-])/, ') \1')

        Groonga['tweets'].select(q)
      end
    end
  end
end
