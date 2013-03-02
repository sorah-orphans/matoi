require 'spec_helper'
require 'json'
require 'matoi/tweet'
require 'matoi/config'
require 'time'

describe Matoi::Tweet, groonga: true do
  let(:config) { Matoi::Config.new({}, File.join(File.dirname(__FILE__), 'fixtures')) }

  def fixture_json(name)
    path = File.expand_path(File.join(__FILE__, '..', 'fixtures', "#{name}.json"))
    JSON.parse(File.read(path))
  end

  before do
    config.open_db
  end

  describe ".add" do
    let(:in_reply_to) { nil }
    let(:tweet) { fixture_json(json_name) }
    let(:record) { Groonga['tweets'][tweet['id']] }
    before do
      described_class.add(in_reply_to) if in_reply_to
      described_class.add(tweet)
    end

    context "with normal tweet" do
      let(:json_name) { 'tweet' }

      it "records a tweet" do
        record.user.should == Groonga['users'][tweet['user']['id']]

        record.text.should == tweet['text']

        created_at = Time.parse(tweet['created_at'])
        record.created_at == created_at
        record.year_month.key == '2013/02'
        record.year_month_day.key == '2013/02/26'
        record.day == 26
        record.hour == 2

        record.source.should == 'example'
        record.user.profile_image_url.should == "http:\/\/a0.twimg.com\/profile_images\/3022880518\/d4a92c61fdb0ee77fb6d29ed644581b7_normal.png"
      end

      it "adds user" do
        Groonga['users'][tweet['user']['id']].screen_name == 'sora_h'
      end

      context "with discovered user" do
        prepend_before do
          Groonga['users'].add(5161091, screen_name: 'sora_h')
        end

        it "uses existence user" do
          record.user.should == Groonga['users'][tweet['user']['id']]
        end
      end
    end

    context "with retweeted tweet" do
      let(:json_name) { 'retweet' }
      let(:record) { Groonga['tweets'][tweet['retweeted_status']['id']] }

      it "records retweeted_status" do
        record.user.should == Groonga['users'][tweet['retweeted_status']['user']['id']]
        record.text.should == tweet['retweeted_status']['text']

        created_at = Time.parse(tweet['retweeted_status']['created_at'])
        record.created_at == created_at
        record.year_month.key == '2013/02'
        record.year_month_day.key == '2013/02/26'
        record.day == 26
        record.hour == 2

        record.source.should == 'example'
        record.user.profile_image_url.should == "http:\/\/a0.twimg.com\/profile_images\/3022880518\/d4a92c61fdb0ee77fb6d29ed644581b7_normal.png"
      end

      it "doesn't record root tweet" do
        Groonga['tweets'][tweet['id']].should be_nil
      end

      it "adds retweeter as retweeted_by" do
        retweeter = Groonga['users'][tweet['user']['id']]

        record.retweeted_users.should be_include(retweeter)
      end

      context "then retweeted by another user" do
        prepend_before do
          orig_id = tweet['user']['id']

          tweet['user']['id'] = 42
          described_class.add(tweet)

          tweet['user']['id'] = orig_id
        end

        it "adds retweeter as retweeted_by" do
          retweeter_a = Groonga['users'][tweet['user']['id']]
          retweeter_b = Groonga['users'][42]

          record.retweeted_users.size.should == 2
          record.retweeted_users.should be_include(retweeter_a)
          record.retweeted_users.should be_include(retweeter_b)
        end
      end
    end

    context "with reply" do
      let(:json_name) { 'reply' }

      it "records in_reply_to_status_id" do
        record.in_reply_to_status_id.should == 306090637902618624
        record.in_reply_to.should be_nil
      end

      context "when in_reply_to tweet has recorded" do
        let(:in_reply_to) { fixture_json('tweet') }

        it "records in_reply_to" do
          in_reply_to_record = Groonga['tweets'][in_reply_to['id']]

          record.in_reply_to_status_id.should == 306090637902618624
          record.in_reply_to.should == in_reply_to_record
        end
      end
    end

    describe "hashtags" do
      let(:json_name) { 'tweet_with_hashtag' }

      it "records hashtags" do
        tweet['entities']['hashtags'].should_not be_empty
        tweet['entities']['hashtags'].each do |tag|
          hashtag = Groonga['hashtags'][tag['text']]
          hashtag.should_not be_nil
          record.hashtags.should be_include(hashtag)
        end
      end
    end

    describe "mentioned_users" do
      let(:json_name) { 'multiple_mention' }

      it "records mentioned users" do
        tweet['entities']['user_mentions'].should_not be_empty
        tweet['entities']['user_mentions'].each do |u|
          user = Groonga['users'][u['id']]
          user.should_not be_nil
          record.mentioned_users.should be_include(user)
        end
      end
    end

    describe "urls" do
      let(:json_name) { 'tweet_with_url' }

      it "records mentioned users" do
        tweet['entities']['urls'].should_not be_empty
        tweet['entities']['urls'].each do |u|
          url = Groonga['urls'][u['expanded_url']]
          url.should_not be_nil
          record.urls.should be_include(url)
        end
      end
    end
  end

  describe ".query" do
  end

  describe ".hashtags" do
  end

  describe ".users" do
  end

  describe ".all" do
  end

  describe ".user(screen_name)" do
  end

  describe ".hashtag(tag)" do
  end
end

