require 'groonga'
require 'oauth'
require 'yaml'

module Matoi
  class Config
    def self.load(yaml_file)
      self.new(YAML.load_file(yaml_file), File.dirname(yaml_file))
    end

    def initialize(hash, base_path = Dir.pwd)
      @hash = hash
      @base_path = Pathname.new(base_path)
      @credentials = nil
      @access_tokens = {}
      @opened = false
    end

    def consumer
      consumer = @hash[:consumer] || @hash['consumer']
      @consumer ||= OAuth::Consumer.new(consumer[:token]  || consumer['token'],
                                        consumer[:secret] || consumer['secret'],
                                        site: 'https://api.twitter.com/')
    end

    def token_file
      path = @hash[:token_file] || @hash['token_file']
      if path
        if path.start_with?('/')
          path
        else
          @base_path.join(path).to_s
        end
      else
        nil
      end
    end

    def db
      path = @hash[:db_path] || @hash['db_path']
      if path
        if path.start_with?('/')
          path
        else
          @base_path.join(path).to_s
        end
      else
        nil
      end
    end

    def credentials
      if @credentials
        @credentials
      else
        credentials_json = JSON.parse(File.read(token_file))
        @credentials = Hash[credentials_json.map { |u,c| [u, c.map{ |k,v| [k.to_sym, v.to_s] }] }]
      end
    end

    def access_token(user)
      return @access_tokens[user] if @access_tokens[user]

      if credentials[user]
        credential = credentials[user]
        OAuth::AccessToken.new(consumer, credential[:token], credential[:secret])
      else
        nil
      end
    end

    def credential_for_stream(user)
      if credentials[user]
        credential = credentials[user]
        consumer = @hash[:consumer] || @hash['consumer']
        {
          consumer_key:    consumer[:token]  || consumer['token'],
          consumer_secret: consumer[:secret] || consumer['secret'],
          access_key:      credential[:token],
          access_secret:   credential[:secret],
        }
      end
    end

    def open_db
      return if @opened

      if db && File.exists?(db)
        Groonga::Database.open(db)
      else
        Groonga::Database.create(path: db)
      end

      Groonga::Schema.define do |s|
        s.create_table("users", type: :hash, key_type: :unsigned_integer64) do |t|
          t.short_text 'screen_name'
          t.short_text 'profile_image_url'
          t.short_text 'profile_image_url_https'
        end
        s.create_table("user_screen_names", type: :patricia_trie,
                                           key_type: :short_text) do |t|
          t.index 'users.screen_name'
        end

        s.create_table('urls', type: :hash, key_type: :short_text) do |t|
          t.text 'url'
          t.text 'display_url'
          t.text 'title'
        end

        s.create_table("year_months", type: :hash, key_type: :short_text) do |t|
        end
        s.create_table("year_month_days", type: :hash, key_type: :short_text) do |t|
        end

        s.create_table('hashtags', type: :hash, key_type: :short_text) do |t|
        end

        s.create_table("tweets", type: :hash, key_type: :unsigned_integer64) do |t|
          t.reference 'user', 'users'
          t.reference 'mentioned_users', 'users', type: :vector
          t.reference 'favorited_users', 'users', type: :vector
          t.reference 'retweeted_users', 'users', type: :vector
          t.reference 'hashtags', 'hashtags', type: :vector
          t.reference 'urls', 'urls', type: :vector

          t.unsigned_integer64 'in_reply_to_status_id'
          t.reference 'in_reply_to', 'tweets'

          t.wgs84_geo_point 'coordinates'

          t.time 'deleted_at'
          t.time 'created_at'
          t.reference 'year_month'
          t.reference 'year_month_day'
          t.unsigned_integer16 'day'
          t.unsigned_integer16 'hour'

          t.text 'text'

          t.text 'source'
        end

        s.create_table('tweet_terms', key_type: :short_text,
                                      default_tokenizer: 'TokenBigram',
                                      type: :patricia_trie,
                                      normalizer: :NormalizerAuto) do |t|
          t.index("tweets.text")
        end
      end
      @opened = true
    end
  end
end
