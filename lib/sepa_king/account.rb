# encoding: utf-8
module SEPA
  class Account
    include ActiveModel::Validations
    extend Converter

    attr_accessor :name, :iban, :bic, :account_number,
      :initiating_party_org_id_other_scheme_name_code
    convert :name, to: :text

    validates_length_of :name, within: 1..70, allow_nil: true
    validates_length_of :initiating_party_org_id_other_scheme_name_code, within: 1..4, allow_nil: true
    validates_with BICValidator, IBANValidator, message: "%{value} is invalid"

    def initialize(attributes = {})
      attributes.each do |name, value|
        public_send("#{name}=", value)
      end
    end

    def initiating_party_org_id_other_scheme_name_code
      @initiating_party_org_id_other_scheme_name_code || 'CUST'
    end
  end
end
