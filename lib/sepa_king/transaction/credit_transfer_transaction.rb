# encoding: utf-8
module SEPA
  class CreditTransferTransaction < Transaction
    attr_accessor :service_level,
                  :creditor_address,
                  :category_purpose,
                  :debtor_account,
                  :purpose,
                  :structured_remittance_information,
                  :structured_remittance_information_code,
                  :charge_bearer,
                  :destination_currency

    validates_inclusion_of :service_level, :in => %w(SEPA URGP), :allow_nil => true
    validates_inclusion_of :structured_remittance_information_code, in: %w(RADM RPIN FXDR DISP PUOR SCOR), allow_nil: true
    validates_inclusion_of :charge_bearer, in: %w(CRED DEBT SHAR SLEV), allow_nil: true
    validates_length_of :category_purpose, within: 1..4, allow_nil: true
    validates_length_of :purpose, within: 1..35, allow_nil: true
    validates_length_of :structured_remittance_information, within: 1..35, allow_nil: true
    validates_length_of :destination_currency, is: 3, allow_nil: true

    validate do |t|
      t.validate_requested_date_after(Date.today)

      if debtor_account
        errors.add(:debtor_account, 'is not correct') unless debtor_account.valid?
      end
    end

    def initialize(attributes = {})
      super
      self.service_level ||= 'SEPA' if self.currency == 'EUR'
      if service_level
        self.charge_bearer ||= 'SLEV'
      end
    end

    def use_equivalent_amount?
      destination_currency && destination_currency != currency
    end

    def schema_compatible?(schema_name)
      case schema_name
      when PAIN_001_001_03
        !self.service_level || (self.service_level == 'SEPA' && self.currency == 'EUR')
      when PAIN_001_002_03
        self.bic.present? && self.service_level == 'SEPA' && self.currency == 'EUR'
      when PAIN_001_003_03
        self.currency == 'EUR'
      when PAIN_001_001_03_CH_02
        self.currency == 'CHF'
      end
    end
  end
end
