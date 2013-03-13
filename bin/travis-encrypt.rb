#!/usr/bin/env ruby 

require "openssl"
require "base64"

    pub_key = File.open("etc/travis.key.txt", "r").read

    imp_key = OpenSSL::PKey::RSA.new(pub_key)

    puts Base64.encode64(imp_key.public_encrypt(ARGF.read))
