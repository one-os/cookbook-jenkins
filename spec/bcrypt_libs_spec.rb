# encoding: utf-8

require 'rubygems'
gem 'minitest' # ensures you're using the gem, and not the built in MT

require 'minitest/spec'
require 'minitest/autorun'
require 'minitest-colorize'
require 'bcrypt'

require "jbcrypt-0.3m.jar"


jBCrypt = Java::OrgMindrotJbcrypt::BCrypt

@password = "siramo68"

describe "jBCrypt" do
  it "doesn't generate the same salt every time" do
    10.times do
      salt1 = jBCrypt.gensalt()
      salt2 = jBCrypt.gensalt()

      if salt1 != salt2
        return
      end
    end
    fail "expected salts to be different"
  end

  it "accepts hashes generated with different salts" do
    10.times do
      salt1 = jBCrypt.gensalt()
      salt2 = jBCrypt.gensalt()

      if salt1 != salt2
        jBCrypt.checkpw(@password, jBCrypt.hashpw(@password, salt1)).must_equal true
      end
    end
  end

  describe "with the secret as salt" do
    it "generates the same hash twice" do
      hash1 = jBCrypt.hashpw(@password, jBCrypt.gensalt())
      jBCrypt.hashpw(@password, hash1).must_equal hash1
    end
  end

end

describe BCrypt::Password do

  it "generates different hashes at each run" do
    10.times do
      hash1 = BCrypt::Password.create(@password).to_s
      hash2 = BCrypt::Password.create(@password).to_s

      if hash1 != hash2
        return
      end
    end
    fail "expected BCrypt to generate different hashes"
  end

  it "accepts hashes generated with different salts" do
    10.times do
      encrypted_password_1 = BCrypt::Password.create(@password)
      encrypted_password_2 = BCrypt::Password.create(@password)

      if encrypted_password_1.to_s != encrypted_password_2.to_s
        encrypted_password_1.is_password?(@password).must_equal true
        encrypted_password_2.is_password?(@password).must_equal true
      end
    end
  end

  it "uses the same version of the algorithm as jBCrypt" do
    jBCrypt_alogorithm_version = '2'
    BCrypt::Password.create(@password).version.to_s[0].must_equal jBCrypt_alogorithm_version
  end

  it "accepts "

  describe "with the secret as salt" do
    it "generates the same hash twice" do
      cost = 10
      hash1 = BCrypt::Engine.hash_secret(@password, BCrypt::Engine.generate_salt(cost), cost).to_s
      BCrypt::Engine.hash_secret(@password, hash1, cost).must_equal hash1
    end
  end

  describe "with fixed salt" do
    cost = 10
    fixed_salt = BCrypt::Engine.generate_salt(cost)
    it "creates a hash that is valid for jBCrypt" do
      encrypted_password = BCrypt::Engine.hash_secret(@password, fixed_salt, cost).to_s

      encrypted_password.to_s.must_equal jBCrypt.hashpw(@password, encrypted_password)
    end
  end

  it "accepts hashes from jBCrypt" do
    jbcrypt_hash = jBCrypt.hashpw(@password, jBCrypt.gensalt())
    bcrypt_ruby_password = BCrypt::Password.new(jbcrypt_hash)
    bcrypt_ruby_password.is_password?(@password).must_equal true
  end

  it "creates a hash that is valid for jBCrypt" do
    skip "Checking preconditions first"
    encrypted_password = BCrypt::Password.create(@password).to_s
    jBCrypt.checkpw(@password, encrypted_password).must_equal true
  end

end
