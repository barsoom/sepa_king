# encoding: utf-8
require 'spec_helper'

RSpec.describe SEPA::Account do
  describe :new do
    it 'should not accept unknown keys' do
      expect {
        SEPA::Account.new foo: 'bar'
      }.to raise_error(NoMethodError)
    end
  end

  describe :name do
    it 'should accept valid value' do
      expect(SEPA::Account).to accept('Gläubiger GmbH', 'Zahlemann & Söhne GbR', 'X' * 70, for: :name)
    end

    it 'should not accept invalid value' do
      expect(SEPA::Account).not_to accept('', 'X' * 71, for: :name)
    end
  end

  describe :bic do
    it 'should accept valid value' do
      expect(SEPA::Account).to accept('DEUTDEFF', 'DEUTDEFF500', 'SPUEDE2UXXX', for: :bic)
    end

    it 'should not accept invalid value' do
      expect(SEPA::Account).not_to accept('', 'invalid', for: :bic)
    end
  end

  describe '#initiating_party_org_id_other_scheme_name_code' do
    it 'should accept valid value' do
      expect(SEPA::Account).to accept('B', 'BA', 'BAN', 'BANK', for: :initiating_party_org_id_other_scheme_name_code)
    end

    it 'should not accept invalid value' do
      expect(SEPA::Account).not_to accept('BANKZ', '', for: :initiating_party_org_id_other_scheme_name_code)
    end

    it 'returns CUST if not set' do
      expect(described_class.new.initiating_party_org_id_other_scheme_name_code).to eq('CUST')
    end
  end

  describe '#bank_account_type' do
    it 'should accept valid value' do
      expect(SEPA::DebtorAccount).to accept('BBAN', 'BGNR', nil, for: :bank_account_type)
    end

    it 'should not accept invalid value' do
      expect(SEPA::DebtorAccount).not_to accept('', 'FOO', for: :bank_account_type)
    end
  end
end
