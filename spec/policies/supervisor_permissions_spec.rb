require 'rails_helper'

# The supervisor sits between agent and administrator; the agreed rules are listed in config/role_matrix.yml.
RSpec.describe 'Supervisor permissions', type: :policy do
  let(:account) { create(:account) }
  let(:supervisor) { create(:user, account: account, role: :supervisor) }
  let(:supervisor_context) do
    { user: supervisor, account: account, account_user: supervisor.account_users.find_by(account: account) }
  end

  describe ConversationPolicy do
    subject { described_class }

    # The supervisor is not a member of this inbox.
    let(:conversation) { create(:conversation, account: account) }

    permissions :show? do
      it { is_expected.to permit(supervisor_context, conversation) }
    end

    permissions :destroy? do
      it { is_expected.not_to permit(supervisor_context, conversation) }
    end
  end

  describe ContactPolicy do
    subject { described_class }

    let(:contact) { create(:contact, account: account) }

    permissions :export? do
      it { is_expected.to permit(supervisor_context, contact) }
    end

    permissions :import?, :destroy? do
      it { is_expected.not_to permit(supervisor_context, contact) }
    end
  end

  describe ReportPolicy do
    subject { described_class }

    permissions :view? do
      it { is_expected.to permit(supervisor_context, :report) }
    end
  end

  describe CsatSurveyResponsePolicy do
    subject { described_class }

    permissions :index?, :metrics?, :download? do
      it { is_expected.to permit(supervisor_context, :csat_survey_response) }
    end
  end

  describe TeamMemberPolicy do
    subject { described_class }

    let(:team) { create(:team, account: account) }

    permissions :index?, :create?, :update?, :destroy? do
      it { is_expected.to permit(supervisor_context, team) }
    end
  end

  describe TeamPolicy do
    subject { described_class }

    let(:team) { create(:team, account: account) }

    permissions :index?, :show? do
      it { is_expected.to permit(supervisor_context, team) }
    end

    permissions :create?, :update?, :destroy? do
      it { is_expected.not_to permit(supervisor_context, team) }
    end
  end

  describe UserPolicy do
    subject { described_class }

    permissions :index? do
      it { is_expected.to permit(supervisor_context, supervisor) }
    end

    permissions :create?, :update?, :destroy? do
      it { is_expected.not_to permit(supervisor_context, supervisor) }
    end
  end

  describe InboxPolicy do
    subject { described_class }

    let(:inbox) { create(:inbox, account: account) }

    permissions :create?, :update?, :destroy? do
      it { is_expected.not_to permit(supervisor_context, inbox) }
    end
  end

  describe LabelPolicy do
    subject { described_class }

    let(:label) { create(:label, account: account) }

    permissions :index? do
      it { is_expected.to permit(supervisor_context, label) }
    end

    permissions :create?, :update?, :destroy? do
      it { is_expected.not_to permit(supervisor_context, label) }
    end
  end

  describe CustomRolePolicy do
    subject { described_class }

    permissions :index? do
      it { is_expected.to permit(supervisor_context, :custom_role) }
    end

    permissions :create?, :update?, :destroy? do
      it { is_expected.not_to permit(supervisor_context, :custom_role) }
    end
  end

  describe AutomationRulePolicy do
    subject { described_class }

    permissions :index?, :create? do
      it { is_expected.not_to permit(supervisor_context, :automation_rule) }
    end
  end
end
