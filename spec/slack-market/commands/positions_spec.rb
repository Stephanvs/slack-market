require 'spec_helper'

describe SlackMarket::Commands::Positions do
  let(:team) { Fabricate(:team) }
  let(:app) { SlackMarket::Server.new(team: team) }
  let(:client) { app.send(:client) }
  let(:user) { Fabricate(:user) }
  let(:message_command) { SlackRubyBot::Hooks::Message.new }
  before do
    allow(Stripe).to receive(:api_key).and_return('key')
  end
  context 'positions' do
    it 'is a premium feature' do
      expect(message: "#{SlackRubyBot.config.user} positions", user: user.user_id).to respond_with_slack_message(team.premium_text)
    end
    context 'premium team' do
      before do
        team.update_attributes!(premium: true)
      end
      it 'creates a user record', vcr: { cassette_name: 'user_info' } do
        expect do
          expect(message: "#{SlackRubyBot.config.user} positions").to respond_with_slack_message(
            '<@user> does not have any open positions.'
          )
        end.to change(User, :count).by(1)
        user = User.last
        expect(user.user_id).to eq 'user'
        expect(user.user_name).to eq 'username'
      end
      context 'with positions' do
        before do
          allow(Stripe).to receive(:api_key).and_return('key')
          allow(User).to receive(:find_create_or_update_by_slack_id!).and_return(user)
        end
        context 'msft', vcr: { cassette_name: 'msft' } do
          it 'up' do
            Fabricate(:position, user: user, name: 'Microsoft Corporation', symbol: 'MSFT', purchased_price_cents: 28_45)
            expect(message: "#{SlackRubyBot.config.user} positions").to respond_with_slack_message('*MSFT* +46% :green_book:')
          end
          it 'down' do
            Fabricate(:position, user: user, name: 'Microsoft Corporation', symbol: 'MSFT', purchased_price_cents: 128_45)
            expect(message: "#{SlackRubyBot.config.user} positions").to respond_with_slack_message('*MSFT* -147% :closed_book:')
          end
          it 'unchanged' do
            Fabricate(:position, user: user, name: 'Microsoft Corporation', symbol: 'MSFT', purchased_price_cents: 51_91)
            expect(message: "#{SlackRubyBot.config.user} positions").to respond_with_slack_message('*MSFT* :blue_book:')
          end
          it 'only shows open positions' do
            Fabricate(:closed_position, user: user, symbol: 'ZYX')
            Fabricate(:position, user: user, name: 'Microsoft Corporation', symbol: 'MSFT', purchased_price_cents: 51_91)
            expect(message: "#{SlackRubyBot.config.user} positions").to respond_with_slack_message('*MSFT* :blue_book:')
          end
        end
        context 'msft and yahoo', vcr: { cassette_name: 'msft_yahoo' } do
          it 'mixed' do
            Fabricate(:position, user: user, name: 'Microsoft Corporation', symbol: 'MSFT', purchased_price_cents: 28_45)
            Fabricate(:position, user: user, name: 'Yahoo!', symbol: 'YHOO', purchased_price_cents: 38_45)
            expect(message: "#{SlackRubyBot.config.user} positions").to respond_with_slack_message('*MSFT* +44% :green_book:, *YHOO* -37% :closed_book:')
          end
        end
      end
    end
  end
end
