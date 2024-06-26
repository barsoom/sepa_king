# encoding: utf-8
require 'spec_helper'

RSpec.describe SEPA::CreditTransfer do
  let(:message_id_regex) { /SEPA-KING\/[0-9a-z_]{22}/ }
  let(:bank_identifier_not_provided_xpath) { '//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/Othr/Id' }
  let(:credit_transfer) {
    SEPA::CreditTransfer.new name:       'Schuldner GmbH',
                             bic:        'BANKDEFFXXX',
                             iban:       'DE87200500001234567890'
  }

  describe :new do
    it 'should accept missing options' do
      expect {
        SEPA::CreditTransfer.new
      }.to_not raise_error
    end
  end

  describe :add_transaction do
    it 'should add valid transactions' do
      3.times do
        credit_transfer.add_transaction(credit_transfer_transaction)
      end

      expect(credit_transfer.transactions.size).to eq(3)
    end

    it 'should fail for invalid transaction' do
      expect {
        credit_transfer.add_transaction name: ''
      }.to raise_error(ArgumentError)
    end
  end

  describe :to_xml do
    context 'for invalid debtor' do
      it 'should fail' do
        expect {
          SEPA::CreditTransfer.new(name: '').to_xml
        }.to raise_error(SEPA::Error, /Name is too short/)
      end
    end

    context 'setting creditor address with adrline' do
      subject do
        sct = SEPA::CreditTransfer.new name: 'Schuldner GmbH',
                                       iban: 'DE87200500001234567890'

        sca = SEPA::CreditorAddress.new country_code:  'CH',
                                        address_line1: 'Mustergasse 123',
                                        address_line2: '1234 Musterstadt'

        sct.add_transaction name:                   'Telekomiker AG',
                            bic:                    'PBNKDEFF370',
                            iban:                   'DE37112589611964645802',
                            amount:                 102.50,
                            reference:              'XYZ-1234/123',
                            remittance_information: 'Rechnung vom 22.08.2013',
                            creditor_address:       sca

        sct
      end

      it 'should validate against pain.001.003.03' do
        expect(subject.to_xml(SEPA::PAIN_001_003_03)).to validate_against('pain.001.003.03.xsd')
      end
    end

    context 'setting creditor address with structured fields' do
      subject do
        sct = SEPA::CreditTransfer.new name: 'Schuldner GmbH',
                                       iban: 'DE87200500001234567890',
                                       bic:  'BANKDEFFXXX'

        sca = SEPA::CreditorAddress.new country_code:    'CH',
                                        street_name:     'Mustergasse',
                                        building_number: '123',
                                        post_code:       '1234',
                                        town_name:       'Musterstadt'

        sct.add_transaction name:                   'Telekomiker AG',
                            bic:                    'PBNKDEFF370',
                            iban:                   'DE37112589611964645802',
                            amount:                 102.50,
                            reference:              'XYZ-1234/123',
                            remittance_information: 'Rechnung vom 22.08.2013',
                            creditor_address:       sca

        sct
      end

      it 'should validate against pain.001.001.03' do
        expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
      end
    end

    context 'with a bankgiro creditor account' do
      subject do
        sct = credit_transfer

        sct.add_transaction name:                       'Telekomiker AG',
                            account_number:             '123456',
                            clearing_bank_identifier:   '9900', # bankgiro
                            clearing_code:              'SESBA',
                            account_number_proprietary: 'BGNR',
                            amount:                     102.50,
                            reference:                  'XYZ-1234/123',
                            remittance_information:     'Rechnung vom 22.08.2013'

        sct.to_xml(SEPA::PAIN_001_001_03)
      end

      it 'should validate against pain.001.001.03' do
        expect(subject).to validate_against('pain.001.001.03.xsd')
      end

      it 'should contain <CdtrAcct/Id/Othr> with expected <Id> and <SchmeNm/Prtry>' do
        expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAcct/Id/Othr/Id', '123456')
        expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAcct/Id/Othr/SchmeNm/Prtry', 'BGNR')
      end

      it 'should contain <ClrSysMmbId> with expected <MmbId> and <ClrSysId/Cd>' do
        expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAgt/FinInstnId/ClrSysMmbId/MmbId', '9900')
        expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAgt/FinInstnId/ClrSysMmbId/ClrSysId/Cd', 'SESBA')
      end
    end

    context 'with a plusgiro creditor account' do
      subject do
        sct = credit_transfer

        sct.add_transaction name:                     'Telekomiker AG',
                            account_number:           '123456',
                            account_number_code:      'BBAN',
                            clearing_bank_identifier: '9960', # plusgiro
                            clearing_code:            'SESBA',
                            amount:                   102.50,
                            reference:                'XYZ-1234/123',
                            remittance_information:   'Rechnung vom 22.08.2013'

        sct.to_xml(SEPA::PAIN_001_001_03)
      end

      it 'should validate against pain.001.001.03' do
        expect(subject).to validate_against('pain.001.001.03.xsd')
      end

      it 'should contain <CdtrAcct/Id/Othr> with expected <Id> and <SchmeNm/Cd>' do
        expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAcct/Id/Othr/Id', '123456')
        expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAcct/Id/Othr/SchmeNm/Cd', 'BBAN')
      end

      it 'should contain <ClrSysMmbId> with expected <MmbId> and <ClrSysId/Cd>' do
        expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAgt/FinInstnId/ClrSysMmbId/MmbId', '9960')
        expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAgt/FinInstnId/ClrSysMmbId/ClrSysId/Cd', 'SESBA')
      end
    end

    context 'with a bban creditor account' do
      subject do
        sct = credit_transfer

        sct.add_transaction name:                        'Telekomiker AG',
                            account_number:              '123456',
                            account_number_code:         'BBAN',
                            amount:                      102.50,
                            reference:                   'XYZ-1234/123',
                            remittance_information:      'Rechnung vom 22.08.2013'

        sct.to_xml(SEPA::PAIN_001_001_03)
      end

      it 'should validate against pain.001.001.03' do
        expect(subject).to validate_against('pain.001.001.03.xsd')
      end

      it 'should contain <CdtrAcct/Id/Othr> with expected <Id> and <SchmeNm/Cd>' do
        expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAcct/Id/Othr/Id', '123456')
        expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAcct/Id/Othr/SchmeNm/Cd', 'BBAN')
      end
    end

    context 'with debtor identifier' do
      let(:scheme_nm_attributes) { {} }
      let(:bank_account_attributes) {
        {
          iban: 'DE87200500001234567890',
        }
      }

      subject do
        sct = SEPA::CreditTransfer.new name: 'Schuldner GmbH',
                                       **bank_account_attributes,
                                       bic:  'BANKDEFFXXX',
                                       debtor_identifier: 'Debtor Identifier AG',
                                       **scheme_nm_attributes

        sct.add_transaction name:           'Telekomiker AG',
                            account_number: '123456',
                            amount:         102.50

        sct.to_xml(SEPA::PAIN_001_001_03)
      end

      it 'should validate against pain.001.001.03' do
        expect(subject).to validate_against('pain.001.001.03.xsd')
      end

      it 'should contain <GrpHdr/InitgPty/Id/OrgId/Othr> with expected <Id> and <SchmeNm/Cd>' do
        expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/Othr/SchmeNm/Cd', 'CUST')
        expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/Othr/Id', 'Debtor Identifier AG')
      end

      context 'when the SchemeNm is also configured' do
        let(:scheme_nm_attributes) { { initiating_party_org_id_other_scheme_name_code: 'QUUZ' } }

        it 'should render the SchemeNm' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/InitgPty/Id/OrgId/Othr/SchmeNm/Cd', 'QUUZ')
        end
      end

      context 'when the :bank_account_type is also configured' do
        let(:bank_account_attributes) {
          {
            account_number: "123456",
            bank_account_type: 'BGNR',
          }
        }

        it 'should render the Bankgiro code in the Swedbank style' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAcct/Id/Othr/SchmeNm/Prtry', 'BGNR')
        end
      end
    end

    context 'for valid debtor' do
      context 'without BIC (IBAN-only)' do
        subject do
          sct = SEPA::CreditTransfer.new name:       'Schuldner GmbH',
                                         iban:       'DE87200500001234567890'

          sct.add_transaction name:                   'Telekomiker AG',
                              bic:                    'PBNKDEFF370',
                              iban:                   'DE37112589611964645802',
                              amount:                 102.50,
                              reference:              'XYZ-1234/123',
                              remittance_information: 'Rechnung vom 22.08.2013'

          sct
        end

        it 'should create valid XML file' do
          expect(subject.to_xml(SEPA::PAIN_001_003_03)).to validate_against('pain.001.003.03.xsd')
        end

        it 'should fail for pain.001.002.03' do
          expect {
            subject.to_xml(SEPA::PAIN_001_002_03)
          }.to raise_error(SEPA::Error, /Incompatible with schema/)
        end
      end

      context "with UK sort code for the debtor, without BIC" do
        subject do
          sct = SEPA::CreditTransfer.new(
            name:       'Schuldner GmbH',
            account_number:       'DE87200500001234567890'
          )

          sct.add_transaction(
            debtor_account: SEPA::DebtorAccount.new(
              uk_sort_code: '123456',
              bic: 'GENODEF1DTA',
              account_number: '12345678',
            ),
            name:                   'Telekomiker AG',
            bic:                    'PBNKDEFF370',
            iban:                   'DE37112589611964645802',
            amount:                 102.50,
            reference:              'XYZ-1234/123',
            remittance_information: 'Rechnung vom 22.08.2013'
          )

          sct
        end

        it 'should create valid XML file' do
          expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
        end

        it 'should include the sort code in the right place' do
          expect(subject.to_xml(SEPA::PAIN_001_001_03)).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/ClrSysMmbId/MmbId', '123456')
        end

        it "should not include the clause that we don't include bank identifiers" do
          expect(subject.to_xml(SEPA::PAIN_001_001_03)).not_to have_xml(bank_identifier_not_provided_xpath)
        end
      end

      context "when the debtor account has neither a BIC nor a UK sort code" do
        subject do
          sct = SEPA::CreditTransfer.new(
            name:       'Schuldner GmbH',
            account_number:       'DE87200500001234567890'
          )

          sct.add_transaction(
            debtor_account: SEPA::DebtorAccount.new(
              account_number: '12345678',
            ),
            name:                   'Telekomiker AG',
            bic:                    'PBNKDEFF370',
            iban:                   'DE37112589611964645802',
            amount:                 102.50,
            reference:              'XYZ-1234/123',
            remittance_information: 'Rechnung vom 22.08.2013'
          )

          sct
        end

        it 'should create valid XML file' do
          expect(subject.to_xml(SEPA::PAIN_001_001_03)).to validate_against('pain.001.001.03.xsd')
        end

        it 'should include the notice about no bank identifiers' do
          expect(subject.to_xml(SEPA::PAIN_001_001_03)).to have_xml(bank_identifier_not_provided_xpath, 'NOTPROVIDED')
        end
      end

      context 'with BIC' do
        subject do
          sct = credit_transfer

          sct.add_transaction name:                   'Telekomiker AG',
                              bic:                    'PBNKDEFF370',
                              iban:                   'DE37112589611964645802',
                              amount:                 102.50,
                              reference:              'XYZ-1234/123',
                              remittance_information: 'Rechnung vom 22.08.2013'

          sct
        end

        it 'should validate against pain.001.001.03' do
          expect(subject.to_xml).to validate_against('pain.001.001.03.xsd')
        end

        it 'should validate against pain.001.002.03' do
          expect(subject.to_xml('pain.001.002.03')).to validate_against('pain.001.002.03.xsd')
        end

        it 'should validate against pain.001.003.03' do
          expect(subject.to_xml('pain.001.003.03')).to validate_against('pain.001.003.03.xsd')
        end
      end

      context 'without requested_date given' do
        subject do
          sct = credit_transfer

          sct.add_transaction name:                   'Telekomiker AG',
                              bic:                    'PBNKDEFF370',
                              iban:                   'DE37112589611964645802',
                              amount:                 102.50,
                              reference:              'XYZ-1234/123',
                              remittance_information: 'Rechnung vom 22.08.2013'

          sct.add_transaction name:                   'Amazonas GmbH',
                              iban:                   'DE27793589132923472195',
                              amount:                 59.00,
                              reference:              'XYZ-5678/456',
                              remittance_information: 'Rechnung vom 21.08.2013'

          sct.to_xml
        end

        it 'should create valid XML file' do
          expect(subject).to validate_against('pain.001.001.03.xsd')
        end

        it 'should have message_identification' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/GrpHdr/MsgId', message_id_regex)
        end

        it 'should contain <PmtInfId>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtInfId', /#{message_id_regex}\/1/)
        end

        it 'should contain <ReqdExctnDt>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ReqdExctnDt', Date.new(1999, 1, 1).iso8601)
        end

        it 'should contain <PmtMtd>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtMtd', 'TRF')
        end

        it 'should contain <BtchBookg>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/BtchBookg', 'true')
        end

        it 'should contain <NbOfTxs>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/NbOfTxs', '2')
        end

        it 'should contain <CtrlSum>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CtrlSum', '161.50')
        end

        it 'should contain <Dbtr>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/Dbtr/Nm', 'Schuldner GmbH')
        end

        it 'should contain <DbtrAcct>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAcct/Id/IBAN', 'DE87200500001234567890')
        end

        it 'should contain <DbtrAgt>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/DbtrAgt/FinInstnId/BIC', 'BANKDEFFXXX')
        end

        it 'should contain <EndToEndId>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/PmtId/EndToEndId', 'XYZ-1234/123')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/PmtId/EndToEndId', 'XYZ-5678/456')
        end

        it 'should contain <Amt>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Amt/InstdAmt', '102.50')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/Amt/InstdAmt', '59.00')
        end

        it 'should contain <CdtrAgt> for every BIC given' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAgt/FinInstnId/BIC', 'PBNKDEFF370')
          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/CdtrAgt')
        end

        it 'should contain <Cdtr>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Cdtr/Nm', 'Telekomiker AG')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/Cdtr/Nm', 'Amazonas GmbH')
        end

        it 'should contain <CdtrAcct>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/CdtrAcct/Id/IBAN', 'DE37112589611964645802')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/CdtrAcct/Id/IBAN', 'DE27793589132923472195')
        end

        it 'should contain <RmtInf>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/RmtInf/Ustrd', 'Rechnung vom 22.08.2013')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[2]/RmtInf/Ustrd', 'Rechnung vom 21.08.2013')
        end
      end

      context 'with different requested_date given' do
        subject do
          sct = credit_transfer

          sct.add_transaction(credit_transfer_transaction.merge requested_date: Date.today + 1)
          sct.add_transaction(credit_transfer_transaction.merge requested_date: Date.today + 2)
          sct.add_transaction(credit_transfer_transaction.merge requested_date: Date.today + 2)

          sct.to_xml
        end

        it 'should contain two payment_informations with <ReqdExctnDt>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/ReqdExctnDt', (Date.today + 1).iso8601)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/ReqdExctnDt', (Date.today + 2).iso8601)

          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]')
        end

        it 'should contain two payment_informations with different <PmtInfId>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/PmtInfId', /#{message_id_regex}\/1/)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/PmtInfId', /#{message_id_regex}\/2/)
        end
      end

      context 'with different batch_booking given' do
        subject do
          sct = credit_transfer

          sct.add_transaction(credit_transfer_transaction.merge batch_booking: false)
          sct.add_transaction(credit_transfer_transaction.merge batch_booking: true)
          sct.add_transaction(credit_transfer_transaction.merge batch_booking: true)

          sct.to_xml
        end

        it 'should contain two payment_informations with <BtchBookg>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/BtchBookg', 'false')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/BtchBookg', 'true')

          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]')
        end
      end

      context 'with transactions containing different group criteria' do
        subject do
          sct = credit_transfer

          sct.add_transaction(credit_transfer_transaction.merge requested_date: Date.today + 1, batch_booking: false, amount: 1)
          sct.add_transaction(credit_transfer_transaction.merge requested_date: Date.today + 1, batch_booking: true,  amount: 2)
          sct.add_transaction(credit_transfer_transaction.merge requested_date: Date.today + 2, batch_booking: false, amount: 4)
          sct.add_transaction(credit_transfer_transaction.merge requested_date: Date.today + 2, batch_booking: true,  amount: 8)
          sct.add_transaction(credit_transfer_transaction.merge requested_date: Date.today + 2, batch_booking: true, category_purpose: 'SALA',  amount: 6)

          sct.to_xml
        end

        it 'should contain multiple payment_informations' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/ReqdExctnDt', (Date.today + 1).iso8601)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/BtchBookg', 'false')

          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/ReqdExctnDt', (Date.today + 1).iso8601)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/BtchBookg', 'true')

          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]/ReqdExctnDt', (Date.today + 2).iso8601)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]/BtchBookg', 'false')

          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[4]/ReqdExctnDt', (Date.today + 2).iso8601)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[4]/BtchBookg', 'true')

          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[5]/ReqdExctnDt', (Date.today + 2).iso8601)
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[5]/PmtTpInf/CtgyPurp/Cd', 'SALA')
        end

        it 'should have multiple control sums' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/CtrlSum', '1.00')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/CtrlSum', '2.00')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[3]/CtrlSum', '4.00')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[4]/CtrlSum', '8.00')
        end
      end

      context 'with transactions containing different debtor_account' do
        subject do
          sdd = credit_transfer

          debtor_account = SEPA::DebtorAccount.new( name: 'Debtor Inc.',
                                                    bic:  'RABONL2U',
                                                    iban: 'NL08RABO0135742099',
                                                    debtor_identifier: '8001011234'
                                                  )

          sdd.add_transaction(credit_transfer_transaction)
          sdd.add_transaction(credit_transfer_transaction.merge(debtor_account: debtor_account))
          sdd.add_transaction(credit_transfer_transaction.merge(debtor_account: debtor_account))

          sdd.to_xml
        end

        it 'should contain two payment_informations with <Cdtr>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/Dbtr/Nm', 'Schuldner GmbH')
          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[1]/Dbtr/Id/OrgId/Othr/Id')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/Dbtr/Nm', 'Debtor Inc.')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/Dbtr/Id/OrgId/Othr/Id', '8001011234')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/Dbtr/Id/OrgId/Othr/SchmeNm/Cd', 'CUST')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf[2]/CdtTrfTxInf[2]/Cdtr/Nm') # Check that we have two CdtTrfTxInf
        end
      end

      context 'with instruction given' do
        subject do
          sct = credit_transfer

          sct.add_transaction name:                   'Telekomiker AG',
                              iban:                   'DE37112589611964645802',
                              amount:                 102.50,
                              instruction:            '1234/ABC'

          sct.to_xml
        end

        it 'should create valid XML file' do
          expect(subject).to validate_against('pain.001.001.03.xsd')
        end

        it 'should contain <InstrId>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/PmtId/InstrId', '1234/ABC')
        end
      end

      context 'with a different currency given' do
        subject do
          sct = credit_transfer

          sct.add_transaction name:                   'Telekomiker AG',
                              iban:                   'DE37112589611964645802',
                              bic:                    'PBNKDEFF370',
                              amount:                 102.50,
                              currency:               'CHF'

          sct
        end

        it 'should validate against pain.001.001.03' do
          expect(subject.to_xml('pain.001.001.03')).to validate_against('pain.001.001.03.xsd')
        end

        it 'should have a CHF Ccy' do
          doc = Nokogiri::XML(subject.to_xml('pain.001.001.03'))
          doc.remove_namespaces!

          nodes = doc.xpath('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Amt/InstdAmt')
          expect(nodes.length).to eql(1)
          expect(nodes.first.attribute('Ccy').value).to eql('CHF')
        end

        it 'should fail for pain.001.002.03' do
          expect {
            subject.to_xml(SEPA::PAIN_001_002_03)
          }.to raise_error(SEPA::Error, /Incompatible with schema/)
        end

        it 'should fail for pain.001.003.03' do
          expect {
            subject.to_xml(SEPA::PAIN_001_003_03)
          }.to raise_error(SEPA::Error, /Incompatible with schema/)
        end
      end

      context 'with a transaction without a bic' do
        subject do
          sct = credit_transfer

          sct.add_transaction name:                   'Telekomiker AG',
                              iban:                   'DE37112589611964645802',
                              amount:                 102.50

          sct
        end

        it 'should validate against pain.001.001.03' do
          expect(subject.to_xml('pain.001.001.03')).to validate_against('pain.001.001.03.xsd')
        end

        it 'should fail for pain.001.002.03' do
          expect {
            subject.to_xml(SEPA::PAIN_001_002_03)
          }.to raise_error(SEPA::Error, /Incompatible with schema/)
        end

        it 'should validate against pain.001.003.03' do
          expect(subject.to_xml(SEPA::PAIN_001_003_03)).to validate_against('pain.001.003.03.xsd')
        end
      end

      context "with structured long form reference" do
        context "with reference code" do
          subject do
            sct = credit_transfer

            sct.add_transaction name:                                         'Telekomiker AG',
                                iban:                                         'DE37112589611964645802',
                                amount:                                        102.50,
                                structured_remittance_information:            '789456',
                                structured_remittance_information_code:       'SCOR'

            sct.to_xml(SEPA::PAIN_001_001_03)
          end

          it 'should validate against pain.001.001.03' do
            expect(subject).to validate_against('pain.001.001.03.xsd')
          end

          it 'should contain <CdtrRefInf> with expected <Ref> and <Tp/CdOrPrtry/Cd>' do
            expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/RmtInf/Strd/CdtrRefInf/Ref', '789456')
            expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/RmtInf/Strd/CdtrRefInf/Tp/CdOrPrtry/Cd', 'SCOR')
          end
        end

        context "without reference code" do
          subject do
            sct = credit_transfer

            sct.add_transaction name:                                         'Telekomiker AG',
                                iban:                                         'DE37112589611964645802',
                                amount:                                        102.50,
                                structured_remittance_information:            '789456'

            sct.to_xml(SEPA::PAIN_001_001_03)
          end

          it 'should validate against pain.001.001.03' do
            expect(subject).to validate_against('pain.001.001.03.xsd')
          end

          it 'should contain <CdtrRefInf> with expected <Tp/CdOrPrtry/Prtry>' do
            expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/RmtInf/Strd/CdtrRefInf/Tp/CdOrPrtry/Prtry', '789456')
          end
        end
      end

      context "with short form reference" do
        subject do
          sct = credit_transfer

          sct.add_transaction name:                     'Telekomiker AG',
                              iban:                     'DE37112589611964645802',
                              amount:                   102.50,
                              purpose:                  'Test message'

          sct.to_xml(SEPA::PAIN_001_001_03)
        end

        it 'should validate against pain.001.001.03' do
          expect(subject).to validate_against('pain.001.001.03.xsd')
        end

        it 'should contain <Purp> with expected <Prtry>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Purp/Prtry', 'Test message')
        end
      end
    end

    context '#charge_bearer' do
      let(:format) { SEPA::PAIN_001_001_03 }
      subject { credit_transfer.to_xml(format) }

      before do
        credit_transfer.add_transaction(transaction)
      end

      context 'with a specified charge bearer' do
        let(:transaction) do
          {
            name: 'Telekomiker AG',
            iban: 'DE37112589611964645802',
            bic: 'PBNKDEFF370',
            amount: 102.50,
            currency: 'CHF',
            charge_bearer: 'SHAR',
          }
        end

        it 'contains the specified ChrgBr' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ChrgBr', 'SHAR')
        end
      end

      context 'with the default charge bearer and in service_level SEPA (EUR)' do
        let(:transaction) do
          {
            name: 'Telekomiker AG',
            iban: 'DE37112589611964645802',
            bic: 'PBNKDEFF370',
            amount: 102.50,
            currency: 'EUR',
          }
        end

        it 'contains the SLEV ChrgBr' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ChrgBr', 'SLEV')
        end

        it 'contains the SEPA service level code' do
          expect(subject).to have_xml('//PmtInf/PmtTpInf/SvcLvl/Cd', 'SEPA')
        end
      end

      context 'with a specified charge bearer and in service_level SEPA (EUR)' do
        let(:transaction) do
          {
            name: 'Telekomiker AG',
            iban: 'DE37112589611964645802',
            bic: 'PBNKDEFF370',
            amount: 102.50,
            currency: 'EUR',
            charge_bearer: 'SHAR',
          }
        end

        it 'contains the SHAR ChrgBr' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/ChrgBr', 'SHAR')
        end

        it 'contains the SEPA service level code' do
          expect(subject).to have_xml('//PmtInf/PmtTpInf/SvcLvl/Cd', 'SEPA')
        end
      end
    end

    context '#destination_currency' do
      let(:format) { SEPA::PAIN_001_001_03 }
      subject { credit_transfer.to_xml(format) }

      before do
        credit_transfer.add_transaction(transaction)
      end

      context 'with a destination_currency' do
        let(:transaction) do
          {
            name: 'Telekomiker AG',
            iban: 'DE37112589611964645802',
            bic: 'PBNKDEFF370',
            amount: 102.50,
            currency: 'CHF',
            destination_currency: 'EUR'
          }
        end

        it 'contains the specified "destination currency" in <CcyOfTrf>' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Amt/EqvtAmt/Amt[@Ccy="CHF"]', '102.50')
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Amt/EqvtAmt/CcyOfTrf', 'EUR')
        end
      end

      context 'with a destination_currency the same as the currency' do
        let(:transaction) do
          {
            name: 'Telekomiker AG',
            iban: 'DE37112589611964645802',
            bic: 'PBNKDEFF370',
            amount: 102.50,
            currency: 'EUR',
            destination_currency: 'EUR'
          }
        end

        it 'does not contain an "equivalent amount"' do
          expect(subject).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Amt/InstdAmt')
          expect(subject).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/CdtTrfTxInf[1]/Amt/EqvtAmt')
        end
      end
    end

    context 'xml_schema_header' do
      subject { credit_transfer.to_xml(format) }

      let(:xml_header) do
        '<?xml version="1.0" encoding="UTF-8"?>' +
          "\n<Document xmlns=\"urn:iso:std:iso:20022:tech:xsd:#{format}\"" +
          ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' +
          " xsi:schemaLocation=\"urn:iso:std:iso:20022:tech:xsd:#{format} #{format}.xsd\">\n"
      end

      let(:transaction) do
        {
          name: 'Telekomiker AG',
          iban: 'DE37112589611964645802',
          bic: 'PBNKDEFF370',
          amount: 102.50,
          currency: 'CHF'
        }
      end

      before do
        credit_transfer.add_transaction transaction
      end

      context "when format is #{SEPA::PAIN_001_001_03}" do
        let(:format) { SEPA::PAIN_001_001_03 }

        it 'should return correct header' do
          is_expected.to start_with(xml_header)
        end
      end

      context "when format is #{SEPA::PAIN_001_002_03}" do
        let(:format) { SEPA::PAIN_001_002_03 }
        let(:transaction) do
          {
            name: 'Telekomiker AG',
            bic: 'PBNKDEFF370',
            iban: 'DE37112589611964645802',
            amount: 102.50,
            reference: 'XYZ-1234/123',
            remittance_information: 'Rechnung vom 22.08.2013'
          }
        end

        it 'should return correct header' do
          is_expected.to start_with(xml_header)
        end
      end

      context "when format is #{SEPA::PAIN_001_003_03}" do
        let(:format) { SEPA::PAIN_001_003_03 }
        let(:transaction) do
          {
            name: 'Telekomiker AG',
            bic: 'PBNKDEFF370',
            iban: 'DE37112589611964645802',
            amount: 102.50,
            reference: 'XYZ-1234/123',
            remittance_information: 'Rechnung vom 22.08.2013'
          }
        end

        it 'should return correct header' do
          is_expected.to start_with(xml_header)
        end
      end

      context "when format is #{SEPA::PAIN_001_001_03_CH_02}" do
        let(:format) { SEPA::PAIN_001_001_03_CH_02 }
        let(:credit_transfer) do
          SEPA::CreditTransfer.new name: 'Schuldner GmbH',
                                   iban: 'CH5481230000001998736',
                                   bic:  'RAIFCH22'
        end
        let(:transaction) do
          {
            name: 'Telekomiker AG',
            iban: 'DE62007620110623852957',
            amount: 102.50,
            currency: 'CHF',
            reference: 'XYZ-1234/123',
            remittance_information: 'Rechnung vom 22.08.2013'
          }
        end

        let(:xml_header) do
          '<?xml version="1.0" encoding="UTF-8"?>' +
            "\n<Document xmlns=\"http://www.six-interbank-clearing.com/de/#{format}.xsd\"" +
            ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' +
            " xsi:schemaLocation=\"http://www.six-interbank-clearing.com/de/#{format}.xsd  #{format}.xsd\">\n"
        end

        it 'should return correct header' do
          is_expected.to start_with(xml_header)
        end
      end
    end

    context 'local instrument' do
      let(:credit_transfer) { SEPA::CreditTransfer.new name: 'Schuldner GmbH', iban: 'DE37112589611964645802'}
      it "should not contain a LclInstrm element if no local_instrument is given" do
        credit_transfer.add_transaction(credit_transfer_transaction)

        expect(credit_transfer.to_xml(SEPA::PAIN_001_001_03)).not_to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/LclInstrm')
      end

      it "should use the given local_instrument as Prtry if local_instrument is given but local_instrument_key isn't" do
        credit_transfer.add_transaction(credit_transfer_transaction.merge(local_instrument: 'CH01'))
        expect(credit_transfer.to_xml(SEPA::PAIN_001_001_03)).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/LclInstrm/Prtry', 'CH01')
      end

      it "should use the given local_instrument_key as Prtry if local_instrument_key is given and local_instrument_key is Prtry" do
        credit_transfer.add_transaction(credit_transfer_transaction.merge(
          local_instrument: 'CH01',
          local_instrument_key: 'Prtry'
        ))

        expect(credit_transfer.to_xml(SEPA::PAIN_001_001_03)).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/LclInstrm/Prtry', 'CH01')
      end

      it "should use the given local_instrument_key as Cd if local_instrument_key is given and local_instrument_key is Cd" do
        credit_transfer.add_transaction(credit_transfer_transaction.merge(
          local_instrument: 'CH01',
          local_instrument_key: 'Cd'
        ))

        expect(credit_transfer.to_xml(SEPA::PAIN_001_001_03)).to have_xml('//Document/CstmrCdtTrfInitn/PmtInf/PmtTpInf/LclInstrm/Cd', 'CH01')
      end
    end
  end
end
