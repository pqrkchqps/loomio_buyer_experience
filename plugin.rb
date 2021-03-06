module Plugins
  module DiehardFundBuyerExperience
    class Plugin < Plugins::Base

      setup! 'diehard-dot-fund_buyer_experience' do |plugin|
        plugin.enabled = true

        plugin.use_asset 'components/services/chargify_service.coffee'
        plugin.use_asset 'components/decorators/group_page_controller_decorator.coffee'
        plugin.use_component :choose_plan_modal
        plugin.use_component :support_diehard_fund_modal
        plugin.use_component :subscription_success_modal
        plugin.use_component :upgrade_plan_card, outlet: :before_group_page_column_right
        plugin.use_component :manage_group_subscription_link, outlet: :after_group_actions_manage_memberships

        plugin.use_translations 'config/locales', :diehard_fund_buyer_experience

        plugin.use_class_directory 'app/models'
        plugin.use_class_directory 'app/admin'
        plugin.use_class_directory 'app/controllers'
        plugin.use_class_directory 'app/helpers'
        plugin.use_class_directory 'app/services'

        plugin.use_route :post, 'groups/:id/use_gift_subscription', 'groups#use_gift_subscription'
        plugin.extend_class API::GroupsController do
          load_resource only: [:use_gift_subscription], find_by: :key
          def use_gift_subscription
            if SubscriptionService.available?
              SubscriptionService.new(resource, current_user).start_gift!
              respond_with_resource
            else
              respond_with_standard_error ActionController::BadRequest, 400
            end
          end
        end

        plugin.extend_class Group do
          belongs_to :subscription, dependent: :destroy
          validates :subscription, absence: true, if: :is_subgroup?
        end

        plugin.extend_class GroupSerializer do
          attributes :subscription_kind,
                     :subscription_plan,
                     :subscription_payment_method,
                     :subscription_expires_at
          def subscription_kind
            subscription&.kind
          end

          def subscription_plan
            subscription&.plan
          end

          def subscription_payment_method
            subscription&.payment_method
          end

          def subscription_expires_at
            subscription&.expires_at
          end

          def subscription
            @subscription ||= object.subscription
          end
        end

        plugin.extend_class Queries::GroupAnalytics do
          module SubscriptionStats
            def stats
              super.merge(is_trial:   @group.subscription&.kind == 'trial',
                          expires_at: @group.subscription&.expires_at,)
            end
          end
          prepend SubscriptionStats
        end

        plugin.use_events do |event_bus|
          event_bus.listen('group_create')  { |group| SubscriptionService.new(group).start_gift! if group.is_parent? }
          event_bus.listen('group_archive') { |group| SubscriptionService.new(group).end_subscription! if group.is_parent? }
        end

        plugin.use_factory :subscription do
          kind :trial
          expires_at 1.month.from_now
        end

        plugin.use_database_table :subscriptions do |t|
          t.string  :kind
          t.date    :expires_at
          t.date    :trial_ended_at
          t.date    :activated_at
          t.integer :chargify_subscription_id
          t.string  :plan
          t.string  :payment_method, default: :chargify, null: false
        end

        plugin.use_test_route :setup_group_on_free_plan do
          group = Group.new(name: 'Ghostbusters', is_visible_to_public: true)
          GroupService.create(group: group, actor: patrick)
          group.add_member! jennifer
          sign_in patrick
          redirect_to group_url(group)
        end

        plugin.use_test_route :setup_old_group_on_free_plan do
          create_group.experiences['bx_choose_plan'] = false
          create_group.save
          GroupService.create(group: create_group, actor: patrick)
          sign_in patrick
          Membership.find_by(user: patrick, group: create_group).update(created_at: 1.week.ago)
          redirect_to group_url(create_group)
        end

        plugin.use_test_route :setup_group_on_paid_plan  do
          GroupService.create(group: create_group, actor: patrick)
          subscription = create_group.subscription
          subscription.update_attribute :kind, 'paid'
          sign_in patrick
          redirect_to group_url(create_group)
        end

        plugin.use_test_route :setup_group_after_chargify_success do
          create_group.save
          sign_in patrick
          redirect_to group_url create_group, chargify_success: true
        end
      end

    end
  end
end
