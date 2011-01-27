require 'test_helper'

class NetaxeptTest < Test::Unit::TestCase
  def setup
    @gateway = NetaxeptGateway.new(
    :login => 'login',
    :password => 'password'
    )

    @amount = 100

    @options = {
      :order_id => '1'
    }
    
    @transaction_id = 'b127f98b77f741fca6bb49981ee6e846'
    
  end


  def test_successful_register
    @gateway.expects(:ssl_get).returns(successful_register_response)
    assert(response = @gateway.register(@amount, @options))
    assert_instance_of NetaxeptGateway::Response, response
    assert_success response
    assert_equal(@transaction_id, response.authorization)
    assert(response.terminal_url, "Terminal url should exist.")
    assert(response.test?)
  end


  def test_successful_auth
    @gateway.expects(:ssl_get).returns(successful_auth_response)
    @options[:transaction_id] = @transaction_id
    assert(response = @gateway.authorize(@options), "Problems running the authorize call.")
    assert_success response
    assert_equal(@transaction_id, response.authorization)
    assert(response.test?)
  end

  def test_failed_auth
    @gateway.expects(:ssl_get).returns(error_response)
    @options[:transaction_id] = @transaction_id
    assert(response = @gateway.authorize(@options), "Problems running the authorize call.")
    assert(!response.success?, "Should not have been successful.")
    assert(response.test?)
  end

  def test_successful_capture
    @options[:transaction_id] = @transaction_id
    @gateway.expects(:ssl_get).returns(successful_capture_response)
    assert(response = @gateway.capture(@money, @options), "Problems running the capture call.")
    assert_success response
    assert_equal(@transaction_id, response.authorization)
    assert(response.test?)
  end

  def test_failed_capture
    @gateway.expects(:ssl_get).returns(error_response)
    @options[:transaction_id] = @transaction_id
    assert(response = @gateway.capture(@money, @options), "Problems running the capture call.")
    assert(!response.success?, "Should not have been successful.")
    assert(response.test?)
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_get).returns(successful_capture_response)
    @options[:transaction_id] = @transaction_id
    assert(response = @gateway.purchase(@options), "Problems running the purchase call.")
    assert_success response
    assert_equal(@transaction_id, response.authorization)
    assert(response.test?)
  end
  
  def test_failed_purchase
    @gateway.expects(:ssl_get).returns(error_response)
    @options[:transaction_id] = @transaction_id
    assert(response = @gateway.purchase(@options), "Problems running the purchase call.")
    assert(!response.success?, "Should not have been successful.")
    assert(response.test?)
  end
  
  def test_successful_credit
    @gateway.expects(:ssl_get).returns(successful_credit_response)
    @options[:transaction_id] = @transaction_id
    assert(response = @gateway.credit(@money, @options), "Problems running the credit call.")
    assert_success response
    assert_equal(@transaction_id, response.authorization)
    assert(response.test?)
  end
  
  def test_failed_credit
    @gateway.expects(:ssl_get).returns(failed_credit_response)
    @options[:transaction_id] = @transaction_id
    assert(response = @gateway.credit(@money, @options), "Problems running the credit call.")
    assert(!response.success?, "Failure message.")
    assert_equal(@transaction_id, response.authorization)
    assert(response.test?)
  end
  
  def test_successful_void
    @gateway.expects(:ssl_get).returns(successful_void_response)
    @options[:transaction_id] = @transaction_id
    assert(response = @gateway.void(@options), "Problems running the void call.")
    assert_success response
    assert_equal(@transaction_id, response.authorization)
    assert(response.test?)
  end
  
  def test_failed_void
    @gateway.expects(:ssl_get).returns(error_response)
    @options[:transaction_id] = @transaction_id
    assert(response = @gateway.void(@options), "Problems running the void call.")
    assert(!response.success?)
    assert(response.test?)
  end
  
  
  def test_successful_query_response
    @gateway.expects(:ssl_get).returns(successful_query_response)
    @options[:transaction_id] = @transaction_id
    assert(response = @gateway.query(@options), "Problems running the query call.")
    assert(response.success?)
    assert(response.test?)
  end

  # 0000000000 ========= 00000000000
  
  private


  def successful_register_response
    %(<?xml version="1.0" ?>
    <RegisterResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <TransactionId>b127f98b77f741fca6bb49981ee6e846</TransactionId>
    </RegisterResponse>)
  end

  def successful_auth_response
    %(<?xml version="1.0" ?>
    <ProcessResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <Operation>AUTH</Operation>
    <ResponseCode>OK</ResponseCode>
    <AuthorizationId>064392</AuthorizationId>
    <TransactionId>b127f98b77f741fca6bb49981ee6e846</TransactionId>
    <ExecutionTime>2009-12-16T11:17:54.633125+01:00</ExecutionTime>
    <MerchantId>9999997</MerchantId>
    </ProcessResponse>)
  end

  def successful_capture_response
    %(<?xml version="1.0" ?>
    <ProcessResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <Operation>CAPTURE</Operation>
    <ResponseCode>OK</ResponseCode>
    <TransactionId>b127f98b77f741fca6bb49981ee6e846</TransactionId>
    <ExecutionTime>2009-12-16T11:40:57.601875+01:00</ExecutionTime>
    <MerchantId>9999997</MerchantId>
    </ProcessResponse>)
  end
  
  def successful_credit_response
    %(<?xml version="1.0" ?>
    <ProcessResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"> 
       <Operation>CREDIT</Operation>
       <ResponseCode>OK</ResponseCode> 
       <TransactionId>b127f98b77f741fca6bb49981ee6e846</TransactionId> 
       <ExecutionTime>2009-12-16T11:40:57.601875+01:00</ExecutionTime> 
       <MerchantId>9999997</MerchantId>
    </ProcessResponse>)
  end
  
  def failed_credit_response
    %(<?xml version="1.0" ?>
    <ProcessResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"> 
       <Operation>CREDIT</Operation>
       <ResponseCode>ERROR</ResponseCode> 
       <TransactionId>b127f98b77f741fca6bb49981ee6e846</TransactionId> 
       <ExecutionTime>2009-12-16T11:40:57.601875+01:00</ExecutionTime> 
       <MerchantId>9999997</MerchantId>
    </ProcessResponse>)
  end
  
  def successful_void_response
    %(<?xml version="1.0" ?>
    <ProcessResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"> 
       <Operation>ANNUL</Operation>
       <ResponseCode>OK</ResponseCode> 
       <TransactionId>b127f98b77f741fca6bb49981ee6e846</TransactionId> 
       <ExecutionTime>2009-12-16T11:40:57.601875+01:00</ExecutionTime> 
       <MerchantId>9999997</MerchantId>
    </ProcessResponse>)
  end
  

  def error_response
    %(<?xml version="1.0" ?>
    <Exception xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <Error xsi:type="AuthenticationException">
    <Message>Authentication failed (TEST)</Message>
    </Error>
    </Exception>)
  end
  
  
  def successful_query_response
    %(<?xml version="1.0" ?> 
    <PaymentInfo xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"> 
    <MerchantId>9999997</MerchantId> 
    <TransactionId>b127f98b77f741fca6bb49981ee6e846</TransactionId> 
    <QueryFinished>2009-12-16T15:18:30.445625+01:00</QueryFinished> - 
    <OrderInformation> 
       <Amount>200</Amount> 
       <Currency>NOK</Currency> 
       <OrderNumber>10011</OrderNumber> 
       <OrderDescription /> 
    </OrderInformation> - 
    <CustomerInformation> 
       <Email /> <IP>91.102.26.94</IP> <PhoneNumber /> 
       <CustomerNumber /> 
    </CustomerInformation>
    <Summary> 
       <AmountCaptured>200</AmountCaptured>  
       <AmountCredited>0</AmountCredited> 
       <Annuled>false</Annuled>
        <Authorized>true</Authorized> 
       <AuthorizationId>064392</AuthorizationId> 
    </Summary>
     <CardInformation> 
       <IssuerId>Visa</IssuerId> <IssuerCountry>NO</IssuerCountry> 
       <MaskedPAN>492500******0004</MaskedPAN> 
       <PaymentMethod>Visa</PaymentMethod> <ExpiryDate>1212</ExpiryDate> 
    </CardInformation>
    <History>
       <TransactionLogLine>
          <DateTime>2009-12-16T10:26:47.243</DateTime> <Description /> 
          <Operation>Register</Operation> 
          <TransactionReconRef /> 
       </TransactionLogLine>
    <TransactionLogLine> 
       <DateTime>2009-12-16T11:17:54.633</DateTime> 
       <Operation>Auth</Operation> 
       <BatchNumber>555</BatchNumber> 
       <TransactionReconRef /> 
    </TransactionLogLine>
    <TransactionLogLine> 
       <Amount>200</Amount> 
       <DateTime>2009-12-16T11:40:57.603</DateTime>
       <Description /> 
       <Operation>Capture</Operation> 
       <BatchNumber>555</BatchNumber> 
       <TransactionReconRef /> 
    </TransactionLogLine> 
    </History> 
    <ErrorLog /> 
    <AuthenticationInformation /> 
    <AvtaleGiroInformation /> 
    </PaymentInfo>)
  end
  

end
