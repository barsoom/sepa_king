require 'spec_helper'

RSpec.describe SEPA::DebtorAccount do
  it 'should initialize a new account' do
    expect(
      SEPA::DebtorAccount.new name:       'Gläubiger GmbH',
                              bic:        'BANKDEFFXXX',
                              iban:       'DE87200500001234567890'
    ).to be_valid
  end

  describe :debtor_identifier do
    it 'should accept valid value' do
      expect(SEPA::DebtorAccount).to accept('a'*35, for: :debtor_identifier)
    end

    it 'should not accept invalid value' do
      expect(SEPA::DebtorAccount).not_to accept('a'*36, for: :debtor_identifier)
    end
  end
end
