# encoding: utf-8

module SEPA
  class CreditTransfer < Message
    self.account_class = DebtorAccount
    self.transaction_class = CreditTransferTransaction
    self.xml_main_tag = 'CstmrCdtTrfInitn'
    self.known_schemas = [ PAIN_001_001_03, PAIN_001_001_03_CH_02, PAIN_001_003_03, PAIN_001_002_03 ]

  private
    # Find groups of transactions which share the same values of some attributes
    def transaction_group(transaction)
      { requested_date: transaction.requested_date,
        local_instrument: transaction.local_instrument,
        local_instrument_key: transaction.local_instrument_key,
        batch_booking: transaction.batch_booking,
        service_level: transaction.service_level,
        category_purpose: transaction.category_purpose,
        account: transaction.debtor_account || account,
        charge_bearer: transaction.charge_bearer,
      }
    end

    def build_payment_informations(builder)
      # Build a PmtInf block for every group of transactions
      grouped_transactions.each do |group, transactions|
        # All transactions with the same requested_date are placed into the same PmtInf block
        builder.PmtInf do
          builder.PmtInfId(payment_information_identification(group))
          builder.PmtMtd('TRF')
          builder.BtchBookg(group[:batch_booking])
          builder.NbOfTxs(transactions.length)
          builder.CtrlSum('%.2f' % amount_total(transactions))
          builder.PmtTpInf do
            if group[:service_level]
              builder.SvcLvl do
                builder.Cd(group[:service_level])
              end
            end
            if group[:category_purpose]
              builder.CtgyPurp do
                builder.Cd(group[:category_purpose])
              end
            end
            if group[:local_instrument]
              builder.LclInstrm do
                if group[:local_instrument_key] == "Cd"
                  builder.Cd(group[:local_instrument])
                else
                  builder.Prtry(group[:local_instrument])
                end
              end
            end
          end
          builder.ReqdExctnDt(group[:requested_date].iso8601)
          builder.Dbtr do
            builder.Nm(group[:account].name) if group[:account].name
            builder.Id do
              builder.OrgId do
                builder.Othr do
                  builder.Id(group[:account].debtor_identifier)
                  builder.SchmeNm do
                    builder.Cd('CUST')
                  end
                end
              end
            end if group[:account].debtor_identifier
          end
          builder.DbtrAcct do
            builder.Id do
              if group[:account].iban
                builder.IBAN(group[:account].iban)
              elsif group[:account].account_number
                builder.Othr do
                  builder.Id(group[:account].account_number)
                  # Swedbank requirement.
                  builder.SchmeNm do
                    case group[:account].bank_account_type
                    when 'BBAN' then builder.Cd('BBAN')
                    when 'BGNR' then builder.Prtry('BGNR')
                    end
                  end if group[:account].bank_account_type
                end
              end
            end
          end
          builder.DbtrAgt do
            builder.FinInstnId do
              if group[:account].bic
                builder.BIC(group[:account].bic)
              end
              if group[:account].uk_sort_code.present?
                builder.ClrSysMmbId do
                  builder.MmbId(group[:account].uk_sort_code)
                end
              end
              if !group[:account].bic && !group[:account].uk_sort_code.present?
                builder.Othr do
                  builder.Id('NOTPROVIDED')
                end
              end
            end
          end
          if group[:charge_bearer]
            builder.ChrgBr(group[:charge_bearer])
          end

          transactions.each do |transaction|
            build_transaction(builder, transaction)
          end
        end
      end
    end

    def build_transaction(builder, transaction)
      builder.CdtTrfTxInf do
        builder.PmtId do
          if transaction.instruction.present?
            builder.InstrId(transaction.instruction)
          end
          builder.EndToEndId(transaction.reference)
        end
        builder.Amt do
          if transaction.use_equivalent_amount?
            builder.EqvtAmt do
              builder.Amt('%.2f' % transaction.amount, Ccy: transaction.currency)
              builder.CcyOfTrf(transaction.destination_currency)
            end
          else
            builder.InstdAmt('%.2f' % transaction.amount, Ccy: transaction.currency)
          end
        end
        if transaction.bic
          builder.CdtrAgt do
            builder.FinInstnId do
              builder.BIC(transaction.bic)
            end
          end
        end

        if transaction.clearing_bank_identifier
          builder.CdtrAgt do
            builder.FinInstnId do
              builder.ClrSysMmbId do
                builder.ClrSysId do
                  builder.Cd(transaction.clearing_code)
                end if transaction.clearing_code
                builder.MmbId(transaction.clearing_bank_identifier)
              end
            end
          end
        end

        builder.Cdtr do
          builder.Nm(transaction.name)
          if transaction.creditor_address
            builder.PstlAdr do
              # Only set the fields that are actually provided.
              # StrtNm, BldgNb, PstCd, TwnNm provide a structured address
              # separated into its individual fields.
              # AdrLine provides the address in free format text.
              # Both are currently allowed and the actual preference depends on the bank.
              # Also the fields that are required legally may vary depending on the country
              # or change over time.
              if transaction.creditor_address.street_name
                builder.StrtNm transaction.creditor_address.street_name
              end

              if transaction.creditor_address.building_number
                builder.BldgNb transaction.creditor_address.building_number
              end

              if transaction.creditor_address.post_code
                builder.PstCd transaction.creditor_address.post_code
              end

              if transaction.creditor_address.town_name
                builder.TwnNm transaction.creditor_address.town_name
              end

              if transaction.creditor_address.country_code
                builder.Ctry transaction.creditor_address.country_code
              end

              if transaction.creditor_address.address_line1
                builder.AdrLine transaction.creditor_address.address_line1
              end

              if transaction.creditor_address.address_line2
                builder.AdrLine transaction.creditor_address.address_line2
              end
            end
          end
        end

        builder.CdtrAcct do
          builder.Id do
            if transaction.iban
              builder.IBAN(transaction.iban)
            end

            if transaction.account_number
              builder.Othr do
                builder.Id(transaction.account_number)
                if transaction.account_number_proprietary
                  builder.SchmeNm do
                    builder.Prtry(transaction.account_number_proprietary)
                  end
                elsif transaction.account_number_code
                  builder.SchmeNm do
                    builder.Cd(transaction.account_number_code)
                  end
                end
              end
            end

          end
        end

        if transaction.remittance_information
          builder.RmtInf do
            builder.Ustrd(transaction.remittance_information)
          end
        elsif transaction.structured_remittance_information
          builder.RmtInf do
            builder.Strd do
              builder.CdtrRefInf do
                builder.Tp do
                  builder.CdOrPrtry do
                    if transaction.structured_remittance_information_code
                      builder.Cd(transaction.structured_remittance_information_code)
                    else
                      builder.Prtry(transaction.structured_remittance_information)
                    end
                  end
                end
                builder.Ref(transaction.structured_remittance_information) if transaction.structured_remittance_information_code
              end
            end
          end
        elsif transaction.purpose
          builder.Purp do
            builder.Prtry(transaction.purpose)
          end
        end
      end
    end
  end
end
