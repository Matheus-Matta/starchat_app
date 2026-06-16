module Monitoring
  class OperationalSnapshotBuilder
    WARNING_THRESHOLD = ENV.fetch('MONITORING_INBOX_WARNING_THRESHOLD_MINUTES', 10).to_i.minutes
    OFFLINE_THRESHOLD = ENV.fetch('MONITORING_INBOX_OFFLINE_THRESHOLD_MINUTES', 30).to_i.minutes
    AVAILABILITY_WEIGHT = { 'online' => 0, 'busy' => 1, 'offline' => 2 }.freeze

    def initialize(account:, warning_threshold: WARNING_THRESHOLD, offline_threshold: OFFLINE_THRESHOLD)
      @account = account
      @warning_threshold = warning_threshold
      @offline_threshold = offline_threshold
      @now = Time.current
    end

    def build
      {
        summary: summary_payload,
        inboxes: inbox_payload,
        agents: agent_payload
      }
    end

    private

    attr_reader :account

    def summary_payload
      current_inboxes = inbox_payload
      {
        total_inboxes: current_inboxes.size,
        online_inboxes: current_inboxes.count { |inbox| inbox[:status] == 'online' },
        warning_inboxes: current_inboxes.count { |inbox| inbox[:status] == 'warning' },
        offline_inboxes: current_inboxes.count { |inbox| inbox[:status] == 'offline' },
        total_agents: agent_payload.size,
        agents_available: agent_payload.count { |agent| agent[:availability_status] == 'online' },
        agents_busy: agent_payload.count { |agent| agent[:availability_status] == 'busy' },
        agents_offline: agent_payload.count { |agent| agent[:availability_status] == 'offline' },
        total_active_conversations: open_conversations_by_inbox.values.sum
      }
    end

    def inbox_payload
      @inbox_payload ||= begin
        inboxes.map do |inbox|
          last_activity = inbox_last_activity(inbox.id)
          online_agents_count = online_inbox_member_counts[inbox.id].to_i
          active_conversations_count = open_conversations_by_inbox[inbox.id].to_i
          derived_status = derive_inbox_status(inbox)
          {
            id: inbox.id,
            name: inbox.name,
            channel_type: inbox.channel_type,
            status: derived_status,
            agents_count: inbox_member_counts[inbox.id] || 0,
            online_agents_count: online_agents_count,
            active_conversations_count: active_conversations_count,
            waiting_conversations_count: waiting_conversations_by_inbox[inbox.id] || 0,
            unassigned_conversations_count: unassigned_conversations_by_inbox[inbox.id] || 0,
            last_activity_at: last_activity&.iso8601
          }
        end.sort_by { |payload| [-payload[:active_conversations_count], payload[:name].downcase] }
      end
    end

    def derive_inbox_status(inbox)
      inbox.channel&.monitoring_status || 'online'
    end

    def agent_payload
      @agent_payload ||= begin
        account_users.map do |account_user|
          next if account_user.user.blank?

          user = account_user.user
          availability = account_user.availability
          {
            id: user.id,
            name: user.name,
            email: user.email,
            availability_status: availability,
            active_conversations_count: agent_conversations[user.id] || 0,
            no_first_reply_count: no_first_reply_by_agent[user.id] || 0,
            waiting_count: waiting_by_agent[user.id] || 0,
            inboxes_count: inboxes_per_agent[user.id] || 0,
            last_activity_at: (account_user.active_at || account_user.updated_at)&.iso8601,
            team_ids: agent_team_ids[user.id] || []
          }
        end.compact.sort do |left, right|
          compare_agents(left, right)
        end
      end
    end

    def compare_agents(left, right)
      availability_score = AVAILABILITY_WEIGHT.fetch(left[:availability_status], 3) <=>
                           AVAILABILITY_WEIGHT.fetch(right[:availability_status], 3)
      return availability_score unless availability_score.zero?

      conversation_score = right[:active_conversations_count] <=> left[:active_conversations_count]
      return conversation_score unless conversation_score.zero?

      left[:name].downcase <=> right[:name].downcase
    end

    def inbox_last_activity(inbox_id)
      last_activity_by_inbox[inbox_id]
    end

    def conversation_scope
      @conversation_scope ||= account.conversations
    end

    def open_conversations_by_inbox
      @open_conversations_by_inbox ||= conversation_scope.open.group(:inbox_id).count
    end

    def waiting_conversations_by_inbox
      @waiting_conversations_by_inbox ||= conversation_scope.open
                                                        .where.not(waiting_since: nil)
                                                        .group(:inbox_id)
                                                        .count
    end

    def unassigned_conversations_by_inbox
      @unassigned_conversations_by_inbox ||= conversation_scope.open.unassigned.group(:inbox_id).count
    end

    def last_activity_by_inbox
      @last_activity_by_inbox ||= conversation_scope.group(:inbox_id).maximum(:last_activity_at)
    end

    def agent_conversations
      @agent_conversations ||= conversation_scope.open.group(:assignee_id).count
    end

    def inboxes
      @inboxes ||= account.inboxes.includes(:channel)
    end

    def inbox_ids
      @inbox_ids ||= inboxes.map(&:id)
    end

    def inbox_member_counts
      @inbox_member_counts ||= begin
        return {} if inbox_ids.empty?

        InboxMember.where(inbox_id: inbox_ids).group(:inbox_id).count
      end
    end

    def inboxes_per_agent
      @inboxes_per_agent ||= begin
        return {} if inbox_ids.empty?

        InboxMember.where(inbox_id: inbox_ids).group(:user_id).count
      end
    end

    def online_inbox_member_counts
      @online_inbox_member_counts ||= begin
        return {} if inbox_ids.empty? || online_user_ids.empty?

        InboxMember.where(inbox_id: inbox_ids, user_id: online_user_ids)
                   .group(:inbox_id)
                   .count
      end
    end

    def online_user_ids
      @online_user_ids ||= OnlineStatusTracker.get_available_user_ids(account.id).map(&:to_i)
    end

    def account_users
      @account_users ||= account.account_users.includes(:user)
    end

    def no_first_reply_by_agent
      @no_first_reply_by_agent ||= conversation_scope.open
                                                      .where(first_reply_created_at: nil)
                                                      .where.not(assignee_id: nil)
                                                      .group(:assignee_id)
                                                      .count
    end

    def waiting_by_agent
      @waiting_by_agent ||= conversation_scope.open
                                               .where.not(waiting_since: nil)
                                               .where.not(assignee_id: nil)
                                               .group(:assignee_id)
                                               .count
    end

    def agent_team_ids
      @agent_team_ids ||= begin
        team_ids_for_account = account.teams.pluck(:id)
        return {} if team_ids_for_account.empty?

        TeamMember.where(team_id: team_ids_for_account)
                  .each_with_object({}) do |tm, hash|
                    (hash[tm.user_id] ||= []) << tm.team_id
                  end
      end
    end
  end
end
