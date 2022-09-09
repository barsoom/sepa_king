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
end
