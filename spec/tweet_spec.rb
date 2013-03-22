require 'spec_helper'
require 'json'
require 'matoi/tweet'
require 'matoi/config'
require 'time'
require 'sewell'

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
    let(:received_user) { nil }

    before do
      described_class.add(in_reply_to) if in_reply_to
      described_class.add(tweet, received_user)
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

    describe "received_user" do
      let(:json_name) { 'tweet' }
      let(:user) do
        u = tweet['user']
        Groonga['users'].add(u['id'], {
          screen_name:             u['screen_name'],
        })
      end
      let(:user2) do
        u = tweet['user']
        Groonga['users'].add(42, {
          screen_name:             u['screen_name'] + '_42',
        })
      end

      let(:received_user) { user }

      context "when not added yet" do
        it "records received user" do
          record.received_users.should == [user]
        end
      end

      context "when added by same user" do
        before do
          described_class.add(tweet, user)
        end

        it "records received user" do
          record.received_users.should == [user]
        end
      end

      context "when added by another user" do
        before do
          record
          described_class.add(tweet, user2)
        end

        it "records received user" do
          record.received_users.should == [user, user2]
        end
      end
    end
  end

  describe ".query" do
    # <sewell-query>
    # user:(screen_name or ID, separated by comma, OR)
    # from:(screen_name or ID, separated by comma, OR)
    # mention:(screen_name or ID, separated by comma, OR)
    # at:YYYYMMDD
    #    YYYYMMDD-YYYYMMDD
    #    (separeted by comma, OR)
    #
    # TODO: test non existence relations
    #
    # Groonga['tweets'].select('user.screen_name:sora_h').each.to_a.map{|_|_['user'].key}
    # Groonga['tweets'].select('user:5161091').each.to_a.map{|_|_['user']['screen_name']}
    # Groonga['tweets'].select('mentioned_users:5161091') 
    # Groonga['tweets'].select('mentioned_users:5161091000') 

    describe "querying" do
      before do
        %w(deletion mention multiple_mention reply retweet tweet tweet_with_hashtag tweet_with_url).each do |json|
          described_class.add(fixture_json(json))
        end

        dummy_tweets = Groonga['tweets'].select('text:this-should-not-be-found')
        dummy_tweets.size.should be_zero

        @query = nil
        Groonga['tweets'].stub(:select) do |query|
          @query = query
          dummy_tweets
        end
      end

      subject { @query }


      describe "sewell-query" do
        it "generates query using Sewell" do
          Sewell.should_receive(:generate).with('aaa', %w[text]).and_return('DUMMY_QUERY')

          expect { described_class.query('aaa') }.to \
            change { @query }.to('DUMMY_QUERY')
        end
      end

      describe "user filter" do
        context "with user_id" do
          it "generates user column query" do
            query = 'user:5161091'
            expect { described_class.query(query) }.to \
              change { @query }.to('( user:5161091 OR mentioned_users:5161091 )')
          end

          context "with multiple" do
            it "generates user column query for all" do
              query = 'user:5161091,608190778'
              expect { described_class.query(query) }.to \
                change { @query }.to(
                  '( user:5161091 OR mentioned_users:5161091 ' \
                  'OR user:608190778 OR mentioned_users:608190778 ' \
                  ')')
            end
          end
        end

        context "with screen_name" do
          it "generates user column query" do
            query = 'user:sora_h'
            expect { described_class.query(query) }.to \
              change { @query }.to('( user:5161091 OR mentioned_users:5161091 )')
          end

          context "with multiple" do
            it "generates user column query" do
              query = 'user:sora_h,sora_her'

              expect { described_class.query(query) }.to \
                change { @query }.to(
                  '( user:5161091 OR mentioned_users:5161091 ' \
                  'OR user:608190778 OR mentioned_users:608190778 ' \
                  ')')

            end
          end

          context "with multiple (user:)" do
            it "generates user column query" do
              query = 'user:sora_h user:sora_her'

              expect { described_class.query(query) }.to \
                change { @query }.to(
                  '( user:5161091 OR mentioned_users:5161091 ' \
                  'OR user:608190778 OR mentioned_users:608190778 ' \
                  ')')

            end
          end
        end

        context "when screen_name and user_id has mixed" do
          it "generates user column query" do
            query = 'user:5161091,sora_her'

            expect { described_class.query(query) }.to \
              change { @query }.to(
                '( user:5161091 OR mentioned_users:5161091 ' \
                'OR user:608190778 OR mentioned_users:608190778 ' \
                ')')
          end
        end

        context "with keyword" do
          it "generates user column query" do
            query = 'a user:5161091'
            expect { described_class.query(query) }.to \
              change { @query }.to('( text:@a ) + ( user:5161091 OR mentioned_users:5161091 )')
          end
        end

        context "with minus" do
          it "generates user column query" do
            query = 'a -user:5161091'
            expect { described_class.query(query) }.to \
              change { @query }.to('( text:@a ) - ( user:5161091 OR mentioned_users:5161091 )')
          end

          context "without plus" do
            it "raises error"
          end

          context "and plus" do
            it "generates user column query" do
              query = 'a -user:5161091 user:sora_her'
              expect { described_class.query(query) }.to \
                change { @query }.to('( text:@a ) + ( user:608190778 OR mentioned_users:608190778 ) - ( user:5161091 OR mentioned_users:5161091 )')
            end
          end
        end
      end

      describe "from filter" do
        context "with user_id" do
          it "generates user column query" do
            query = 'from:5161091'
            expect { described_class.query(query) }.to \
              change { @query }.to('( user:5161091 )')
          end

          context "with multiple" do
            it "generates user column query for all" do
              query = 'from:5161091,608190778'
              expect { described_class.query(query) }.to \
                change { @query }.to('( user:5161091 OR user:608190778 )')
            end
          end
        end

        context "with screen_name" do
          it "generates user column query" do
            query = 'from:sora_h'
            expect { described_class.query(query) }.to \
              change { @query }.to('( user:5161091 )')
          end

          context "with multiple" do
            it "generates user column query" do
              query = 'from:sora_h,sora_her'

              expect { described_class.query(query) }.to \
                change { @query }.to('( user:5161091 OR user:608190778 )')
            end
          end

          context "with multiple (user:)" do
            it "generates user column query" do
              query = 'from:sora_h from:sora_her'

              expect { described_class.query(query) }.to \
                change { @query }.to('( user:5161091 OR user:608190778 )')
            end
          end
        end

        context "when screen_name and user_id has mixed" do
          it "generates user column query" do
            query = 'from:5161091,sora_her'

            expect { described_class.query(query) }.to \
              change { @query }.to('( user:5161091 OR user:608190778 )')
          end
        end

        context "with keyword" do
          it "generates user column query" do
            query = 'a from:5161091'
            expect { described_class.query(query) }.to \
              change { @query }.to('( text:@a ) + ( user:5161091 )')
          end
        end

        context "with minus" do
          it "generates user column query" do
            query = 'a -from:5161091'
            expect { described_class.query(query) }.to \
              change { @query }.to('( text:@a ) - ( user:5161091 )')
          end

          context "without plus" do
            it "raises error"
          end

          context "and plus" do
            it "generates user column query" do
              query = 'a -from:5161091 from:sora_her'
              expect { described_class.query(query) }.to \
                change { @query }.to('( text:@a ) + ( user:608190778 ) - ( user:5161091 )')
            end
          end
        end
      end

      describe "mention filter" do
        context "with user_id" do
          it "generates user column query" do
            query = 'mention:5161091'
            expect { described_class.query(query) }.to \
              change { @query }.to('( mentioned_users:5161091 )')
          end

          context "with multiple" do
            it "generates user column query for all" do
              query = 'mention:5161091,608190778'
              expect { described_class.query(query) }.to \
                change { @query }.to('( mentioned_users:5161091 OR mentioned_users:608190778 )')
            end
          end
        end

        context "with screen_name" do
          it "generates user column query" do
            query = 'mention:sora_h'
            expect { described_class.query(query) }.to \
              change { @query }.to('( mentioned_users:5161091 )')
          end

          context "with multiple" do
            it "generates user column query" do
              query = 'mention:sora_h,sora_her'

              expect { described_class.query(query) }.to \
                change { @query }.to('( mentioned_users:5161091 OR mentioned_users:608190778 )')
            end
          end

          context "with multiple (mentioned_users:)" do
            xit "generates user column query" do
              query = 'mention:sora_h mention:sora_her'

              expect { described_class.query(query) }.to \
                change { @query }.to('( mentioned_users:5161091 ) + ( mentioned_users:608190778 )')
            end
          end
        end

        context "when screen_name and user_id has mixed" do
          it "generates user column query" do
            query = 'mention:5161091,sora_her'

            expect { described_class.query(query) }.to \
              change { @query }.to('( mentioned_users:5161091 OR mentioned_users:608190778 )')
          end
        end

        context "with keyword" do
          it "generates user column query" do
            query = 'a mention:5161091'
            expect { described_class.query(query) }.to \
              change { @query }.to('( text:@a ) + ( mentioned_users:5161091 )')
          end
        end

        context "with minus" do
          it "generates user column query" do
            query = 'a -mention:5161091'
            expect { described_class.query(query) }.to \
              change { @query }.to('( text:@a ) - ( mentioned_users:5161091 )')
          end

          context "without plus" do
            it "raises error"
          end

          context "and plus" do
            it "generates user column query" do
              query = 'a -mention:5161091 mention:sora_her'
              expect { described_class.query(query) }.to \
                change { @query }.to('( text:@a ) + ( mentioned_users:608190778 ) - ( mentioned_users:5161091 )')
            end
          end
        end
      end

      describe "at filter" do
        it "generates year_month_day column query" do
          query = 'at:20130402'
          expect { described_class.query(query) }.to \
            change { @query }.to('( year_month_day:2013/04/02 )')
        end

        context "with range" do
          it "generates year_month_day column query" do
            query = 'at:20130402..20130405'
            expect { described_class.query(query) }.to \
              change { @query }.to('( year_month_day:2013/04/02 OR' \
                                    ' year_month_day:2013/04/03 OR' \
                                    ' year_month_day:2013/04/04 OR' \
                                    ' year_month_day:2013/04/05 )')
          end
        end

        context "when specified multiple" do
          it "joins the specified conditions with OR" do
            query = 'at:20130402..20130405 at:20121212'
            expect { described_class.query(query) }.to \
              change { @query }.to('( year_month_day:2013/04/02 OR' \
                                    ' year_month_day:2013/04/03 OR' \
                                    ' year_month_day:2013/04/04 OR' \
                                    ' year_month_day:2013/04/05 OR' \
                                    ' year_month_day:2012/12/12 )')
          end
        end

        context "with keyword" do
          it "generates year_month_day column query" do
            query = 'foo at:20130402'
            expect { described_class.query(query) }.to \
              change { @query }.to('( text:@foo ) + ( year_month_day:2013/04/02 )')
          end
        end

        context "with minus" do
          it "generates year_month_day column query" do
            query = 'foo -at:20130402'
            expect { described_class.query(query) }.to \
              change { @query }.to('( text:@foo ) - ( year_month_day:2013/04/02 )')
          end

          context "without plus" do
            it "raises error"
          end

          context "and plus" do
            it "generates year_month_day column query" do
              query = 'foo at:20130401 -at:20130402'
              expect { described_class.query(query) }.to \
                change { @query }.to('( text:@foo ) + ' \
                                     '( year_month_day:2013/04/01 ) - ' \
                                     '( year_month_day:2013/04/02 )')
            end
          end
        end
      end
    end

    describe "result" do
      let(:query) { 'a' }
      subject { described_class.query(query) }

      it "returns Groonga::Table" do
        subject.should be_a_kind_of(Groonga::Table)
      end
    end
  end
end

