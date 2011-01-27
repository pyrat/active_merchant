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
      def register(money, options = {})
        requires!(options, :order_id)

        post = {}
        add_credentials(post, options)
        add_new_transaction(post, options)
        add_terminal(post, options)
        add_order(post, money, options)
        commit('REGISTER', post)
      end
      
      def purchase(options = {})
        requires!(options, :transaction_id)
        
        post = {}
        add_credentials(post, options)
        add_existing_transaction(post, options)
        commit('SALE', post)
      end
      
      def authorize(options = {})
        requires!(options, :transaction_id)
        
        post = {}
        add_credentials(post, options)
        add_existing_transaction(post, options)
        commit('AUTH', post)
      end
      
      def capture(money, options = {})
        requires!(options, :transaction_id)
        
        post = {}
        add_credentials(post, options)
        add_existing_transaction(post, options)
        add_transaction_amount(post, money)
        commit('CAPTURE', post)
      end
      
      def credit(money, options = {})
        requires!(options, :transaction_id)
        
        post = {}
        add_credentials(post, options)
        add_existing_transaction(post, options)
        add_transaction_amount(post, money)
        commit('CREDIT', options)
      end
      
      def void(options = {})
        requires!(options, :transaction_id)
        
        post = {}
        add_credentials(post, options)
        add_existing_transaction(post, options)
        commit('ANNUL', post)
      end
      
      def query(options = {})
        requires!(options, :transaction_id)
        
        post = {}
        add_credentials(post, options)
        add_existing_transaction(post, options)
        commit('QUERY', post)
      end


      def test?
        @options[:test] || Base.gateway_mode == :test
      end

      
      # 0000000000 ========= 00000000000
      
      private

      def add_credentials(post, options)
        post[:merchantId] = @options[:login]
        post[:token] = @options[:password]
      end

      def add_order(post, money, options)
        post[:orderNumber] = options[:order_id]
        post[:currencyCode] = (options[:currency] || currency(money))
        post[:amount] = amount(money)
      end

      def add_terminal(post, options)
        post[:serviceType] = 'B'
        post[:orderDescription] = options[:description]
        post[:language] = options[:language] || 'nb_NO'
        post[:redirectUrl] = options[:redirect_url] || 'http://example.com'
      end

      def add_transaction_amount(post, money)
        post[:transactionAmount] = money
      end

      def add_new_transaction(post, options)
        post[:transactionId] = generate_transaction_id(options)
      end
      
      def add_existing_transaction(post, options)
        post[:transactionId] = options[:transaction_id]
      end


      # This communicates with Netaxept
      def commit(action, parameters)
        parameters[:operation] = action

        response = {:success => false}

        catch(:exception) do
          
          case action
          when 'REGISTER'
            commit_transaction_register(response, parameters)
          when 'SALE','AUTH','CAPTURE','CREDIT','ANNUL'
            commit_transaction_process(action, response, parameters)
          when 'QUERY'
            commit_transaction_query(response, parameters)
          else
            raise ArgumentError, "Unsupported action."
          end
          
        end


        Response.new(response[:success], response[:message], response, :test => test?, :authorization => response[:authorization],
        :terminal_url => response[:terminal_url])
      end

      def commit_transaction_register(response, parameters)
        response[:setup] = parse(ssl_get(build_url("Netaxept/Register.aspx", parameters)))
        process(response, :setup)
        add_terminal_url(response, parameters)
      end
      
      def commit_transaction_process(action, response, parameters)
        key = action.downcase.to_sym
        response[key] = parse(ssl_get(build_url("Netaxept/Process.aspx", parameters)))
        process(response, key)
      end
      
      def commit_transaction_query(response, parameters)
        response[:query] = parse(ssl_get(build_url("Netaxept/Query.aspx", parameters)))
        process(response, :query)
      end

      # need to add success in here
      def process(response, key)
        if response[key][:container] =~ /Exception|Error/
          response[:message] = response[key]['Error']['Message']
          
          if response[key]['Error'] && response[key]['Error']['Result']
            response[:authorization] = response[key]['Error']['Result']['TransactionId']
          else
            response[:authorization] = "error"
          end
          throw :exception
        else
          response[:authorization] = response[key]["TransactionId"]
          
          # This is only run if there wasnt an exception.
          response[:success] = was_successful?(response, key)
        end
      end
      
      def was_successful?(response, key)
        if response[key]['ResponseCode'] && response[key]['ResponseCode'] == 'OK'
          true
        elsif !response[key]['ResponseCode']
          true
        else
          false
        end
      end

      def add_terminal_url(response, parameters)
        params = {
          :MerchantID => parameters[:merchantId],
          :TransactionID => response[:authorization]
        }
        response[:terminal_url] = build_url('terminal/default.aspx', params)
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
        attr_reader :error_detail, :terminal_url
        def initialize(success, message, raw, options)
          super
          @terminal_url = options[:terminal_url]
          # extract error detail if there are errors.
        end
      end
    end
  end
end
