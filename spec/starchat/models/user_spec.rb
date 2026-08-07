# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  let!(:user) { create(:user) }

  describe 'user creation' do
    let!(:existing_user) { create(:user) }
    let(:new_user) { build(:user) }

    it 'does not block user creation based on local license limits' do
      new_user.valid?
      expect(new_user.errors[:base]).to be_empty
    end

    it 'does not add error when trying to update an existing user' do
      existing_user.update(name: 'new name')
      existing_user.valid?
      expect(existing_user.errors[:base]).to be_empty
    end
  end

  describe 'audit log' do
    before do
      create(:user)
    end

    context 'when user is created' do
      it 'has no associated audit log created' do
        expect(Audited::Audit.where(auditable_type: 'User', action: 'create').count).to eq 0
      end
    end
  end
end
