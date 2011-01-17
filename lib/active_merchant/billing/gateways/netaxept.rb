require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NetaxeptGateway < Gateway
      TEST_URL = 'https://epayment-test.bbs.no/'
      LIVE_URL = 'https://epayment.bbs.no/'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['NO', 'DK', 'SE', 'FI']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :maestro, :bank_axess]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.betalingsterminal.no/Netthandel-forside/'
      
      # The name of the gateway
      self.display_name = 'BBS Netaxept'
      
      self.money_format = :cents
      
      self.default_currency = 'NOK'
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end
      
      
      # Need to get the API info for the merchant hosted solution here.
      def register(money, creditcard, options = {})
        requires!(options, :order_id)
        
        post = {}
        add_credentials(post, options)
        add_transaction(post, options)
        add_order(post, money, options)
        commit('Register', post)
      end
        
      
      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)

        post = {}
        add_credentials(post, options)
        add_transaction(post, options)
        add_order(post, money, options)
        add_creditcard(post, creditcard)
        commit('Sale', post)
      end                       

      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)

        post = {}
        add_credentials(post, options)
        add_transaction(post, options)
        add_order(post, money, options)
        add_creditcard(post, creditcard)
        commit('Auth', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_credentials(post, options)
        add_authorization(post, authorization, money)
        commit('Capture', post, false)
      end

      def credit(money, authorization, options = {})
        post = {}
        add_credentials(post, options)
        add_authorization(post, authorization, money)
        commit('Credit', post, false)
      end

      def void(authorization, options = {})
        post = {}
        add_credentials(post, options)
        add_authorization(post, authorization)
        commit('Annul', post, false)
      end

      def test?
        @options[:test] || Base.gateway_mode == :test
      end

    
      private
      
      def add_credentials(post, options)
        post[:merchantId] = @options[:login]
        post[:token] = @options[:password]
      end
      
      def add_authorization(post, authorization, money=nil)
        post[:transactionId] = authorization
        post[:transactionAmount] = amount(money) if money
      end
      
      def add_transaction(post, options)
        post[:transactionId] = generate_transaction_id(options)
        post[:serviceType] = 'M'
        post[:redirectUrl] = 'http://example.com'
      end
      
      def add_order(post, money, options)
        post[:orderNumber] = options[:order_id]
        post[:amount] = amount(money)
        post[:currencyCode] = (options[:currency] || currency(money))
      end
      
     
      # def add_creditcard(post, creditcard)
      #         brand = Gateway.card_brand(creditcard)
      #         prefix = CARD_TYPE_PREFIXES[brand]
      #         unless prefix
      #           raise ArgumentError.new("Card type #{brand} not supported.")
      #         end
      # 
      #         post[:creditcard] = {}
      #         post[:creditcard][:"#{prefix}a"] = creditcard.number
      #         post[:creditcard][:"#{prefix}m"] = format(creditcard.month, :two_digits)
      #         post[:creditcard][:"#{prefix}y"] = format(creditcard.year, :two_digits)
      #         post[:creditcard][:"#{prefix}c"] = creditcard.verification_value
      #       end
      
      def commit(action, parameters)
        parameters[:action] = action

        response = {:success => false}

        catch(:exception) do
          
          case action
          when 'Register'
            commit_transaction_register(response, parameters)
          else
            commit_transaction(response, parameters)
          end
          response[:success] = true
        end
        
        
        Response.new(response[:success], response[:message], response, :test => test?, :transaction_id => response[:message])
      end
      
      def commit_transaction_register(response, parameters)
        response[:setup] = parse(ssl_get(build_url("Netaxept/Register.aspx", parameters)))
        process(response, :setup)
      end
      
      def commit_transaction(response, parameters)
        true
      end
      

      def process(response, key)
        if response[key][:container] =~ /Exception|Error/
          response[:message] = response[key]['Message']
          throw :exception
        else
          response[:message] = response[key]["TransactionId"]
        end
      end
      
      def parse(result)
        doc = REXML::Document.new(result)
        extract_xml(doc.root).merge(:container => doc.root.name)
      end
      
      def extract_xml(element)
        if element.has_elements?
          hash = {}
          element.elements.each do |e|
            hash[e.name] = extract_xml(e)
          end
          hash
        else
          element.text
        end
      end
      
      def url
        (test? ? TEST_URL : LIVE_URL)
      end
      
      def generate_transaction_id(options)
        Digest::MD5.hexdigest("#{options.inspect}+#{Time.now}+#{rand}")
      end
      
      def pick(hash, *keys)
        keys.inject({}){|h,key| h[key] = hash[key] if hash[key]; h}
      end
      
      def build_url(base, parameters=nil)
        url = "#{test? ? TEST_URL : LIVE_URL}"
        url << base
        if parameters
          url << '?'
          url << encode(parameters)
        end
        url
      end
      
      def encode(hash)
        hash.collect{|(k,v)| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join('&')
      end
      
      class Response < Billing::Response
        attr_reader :error_detail, :transaction_id
        def initialize(success, message, raw, options)
          super
          @transaction_id = options[:transaction_id]
          # need to add some more decent responses here.
          # extract error detail if there are errors.
        end
      end
    end
  end
end

