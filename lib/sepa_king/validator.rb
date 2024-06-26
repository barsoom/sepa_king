# encoding: utf-8
module SEPA
  class IBANValidator < ActiveModel::Validator
    # IBAN2007Identifier (taken from schema)
    REGEX = /\A[A-Z]{2,2}[0-9]{2,2}[a-zA-Z0-9]{1,30}\z/

    def validate(record)
      field_name = options[:field_name] || :iban
      value = record.send(field_name).to_s

      if value.present?
        unless IBANTools::IBAN.valid?(value) && value.match?(REGEX)
          record.errors.add(field_name, :invalid, message: options[:message])
        end
      end
    end
  end

  class BICValidator < ActiveModel::Validator
    # AnyBICIdentifier (taken from schema)
    REGEX = /\A[A-Z]{6,6}[A-Z2-9][A-NP-Z0-9]([A-Z0-9]{3,3}){0,1}\z/

    def validate(record)
      field_name = options[:field_name] || :bic
      value = record.send(field_name)

      if value
        unless value.to_s.match?(REGEX)
          record.errors.add(field_name, :invalid, message: options[:message])
        end
      end
    end
  end

  class CreditorIdentifierValidator < ActiveModel::Validator
    REGEX = %r{\A
      [a-zA-Z]{2}                 # ISO country code
      [0-9]{2}                    # Check digits
      [A-Za-z0-9]{3}              # Creditor business code
      [A-Za-z0-9+?/:().,'-]{1,28} # National identifier
    \z}x

    def validate(record)
      field_name = options[:field_name] || :creditor_identifier
      value = record.send(field_name)

      unless valid?(value)
        record.errors.add(field_name, :invalid, message: options[:message])
      end
    end

    def valid?(creditor_identifier)
      return false unless creditor_identifier.to_s.match?(REGEX)

      # In Germany, the identifier has to be exactly 18 chars long
      return (creditor_identifier.length == 18) if creditor_identifier[0..1].match?(/DE/i)

      true
    end
  end

  class DebtorIdentifierValidator < ActiveModel::Validator
    def validate(record)
      field_name = options[:field_name] || :debtor_identifier
      value = record.send(field_name)

      unless valid?(value)
        record.errors.add(field_name, :invalid, message: options[:message])
      end
    end

    def valid?(debtor_identifier)
      debtor_identifier.to_s.length <= 35 # Field is Max35Text
    end
  end

  class MandateIdentifierValidator < ActiveModel::Validator
    REGEX = %r{\A[A-Za-z0-9 +?/:().,'-]{1,35}\z}

    def validate(record)
      field_name = options[:field_name] || :mandate_id
      value = record.send(field_name)

      unless value.to_s.match?(REGEX)
        record.errors.add(field_name, :invalid, message: options[:message])
      end
    end
  end

  class UkSortCodeValidator < ActiveModel::Validator
    REGEX = /\A\d{6}\z/

    def validate(record)
      field_name = options[:field_name] || :uk_sort_code
      value = record.send(field_name)

      # This is the only custom validator that validates an optional field.
      return unless value
      return if value.to_s.match?(REGEX)

      record.errors.add(field_name, :invalid, message: options[:message])
    end
  end
end
