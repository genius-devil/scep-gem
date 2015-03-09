require 'spec_helper'

describe SCEP::PKIOperation::Request do

  let(:ra_keypair)   { generate_keypair }
  let(:misc_keypair) { generate_keypair}
  let(:request)      { SCEP::PKIOperation}
  let(:csr)     { OpenSSL::X509::Request.new read_fixture('self-signed.csr') }
  let(:payload) { csr.to_der }
  let(:p7enc)   { OpenSSL::PKCS7.encrypt([ra_keypair.certificate], payload, SCEP::PKIOperation::Base.create_default_cipher, OpenSSL::PKCS7::BINARY) }
  let(:p7sign)  { OpenSSL::PKCS7.sign(misc_keypair.certificate, misc_keypair.private_key, p7enc.to_der, [misc_keypair.certificate], OpenSSL::PKCS7::BINARY) }

  subject { SCEP::PKIOperation::Request.new(ra_keypair) }

  before do
    subject.x509_store.add_cert(misc_keypair.certificate)
  end

  describe '#decrypt' do
    it 'decrypts the csr in its original format' do
      subject.decrypt(p7sign.to_der)
      expect(subject.csr.to_pem).to eql(csr.to_pem)
    end
  end

  describe '#encrypt' do
    it 'encrypts and signs the CSR' do
      subject.csr = csr
      encrypted = subject.encrypt(misc_keypair.certificate)

      # Might as well use our already tested decryption method above
      request = SCEP::PKIOperation::Request.new(misc_keypair)
      request.add_verification_certificate(ra_keypair.certificate)
      request.decrypt(encrypted)
      expect(request.csr.to_pem).to eql(csr.to_pem)
    end
  end

  describe '#proxy' do
    let(:final_keypair) { generate_keypair }

    it 'decrypts the csr and then re-encrypts it for another target cert' do
      subject.verify_against(ra_keypair.certificate)
      encrypted = subject.proxy(p7sign.to_der, final_keypair.certificate)
      expect(subject.csr.to_pem).to eql(csr.to_pem)

      # Now make sure our new keypair can access & decrypt it
      request = SCEP::PKIOperation::Request.new(final_keypair)
      request.verify_against(ra_keypair.certificate)
      request.decrypt(encrypted)
      expect(request.csr.to_pem).to eql(csr.to_pem)
      # As you can imagine, we should be able to do *n* number of proxies
    end
  end

end