module Spree
  module PaymentGateway    
    def authorize(amount)
      gateway = payment_gateway       
      # ActiveMerchant is configured to use cents so we need to multiply order total by 100
      response = gateway.authorize((amount * 100).to_i, self, gateway_options)      

       # 3ds code derived from http://github.com/andyjeffries/active_merchant/commit/d25199d218e06cb20d61268d39cdb050fe54bd85

      if response.success?
        # create a creditcard_payment for the amount that was authorized

        order.new_payment(self, 0, amount, response.authorization, CreditcardTxn::TxnType::AUTHORIZE) 

      elsif response.requires_3dsecure?
        # save a transaction -- but without a response code
        # store the MD code instead to allow finding of txn later (TODO: abstract)
        transaction = order.new_payment(self, 0, amount, nil, CreditcardTxn::TxnType::AUTHORIZE) 
        transaction.md = response.params["MD"]
        transaction.save
        gateway.form_for_3dsecure_verification(response.params)
      else
        gateway_error(response) 
      end

    end

    # doesn't require CC state - only depends on the parameters
    def complete_3dsecure(params)
      params["VendorTxCode"] = order.number
      response = payment_gateway.complete_3dsecure(params)
      gateway_error(response) unless response.success?          

      txn = CreditcardTxn.find_by_md(params["MD"])
      txn.response_code = response.authorization
      txn.save
    end

    # TODO - check for 3dsecure
    def capture(authorization)
      gw = payment_gateway
      response = gw.capture((authorization.amount * 100).to_i, authorization.response_code, minimal_gateway_options)
      gateway_error(response) unless response.success?          
      creditcard_payment = authorization.creditcard_payment
      creditcard_payment.creditcard_txns.create(:amount => authorization.amount, :response_code => response.authorization, :txn_type => CreditcardTxn::TxnType::CAPTURE)
    end

    # TODO - revise for 3dsecure
    def purchase(amount)
      #combined Authorize and Capture that gets processed by the ActiveMerchant gateway as one single transaction.
      gateway = payment_gateway 
      response = gateway.purchase((amount * 100).to_i, self, gateway_options) 
      gateway_error(response) unless response.success?
      
      
      # create a creditcard_payment for the amount that was purchased
      order.new_payment(self, amount, amount, response.authorization, CreditcardTxn::TxnType::PURCHASE)
    end

    def void
=begin
      authorization = find_authorization
      response = payment_gateway.void(authorization.response_code, minimal_gateway_options)
      gateway_error(response) unless response.success?
      self.creditcard_txns.create(:amount => order.total, :response_code => response.authorization, :txn_type => CreditcardTxn::TxnType::CAPTURE)
=end
    end
    
    def gateway_error(response)
      text = response.params['message'] || 
             response.params['response_reason_text'] ||
             response.message
      msg = "#{I18n.t('gateway_error')} ... #{text}"
      logger.error(msg)
      raise Spree::GatewayError.new(msg)
    end
        
    def gateway_options
      options = {:billing_address => generate_address_hash(address), 
                 :shipping_address => generate_address_hash(order.ship_address)}
      options.merge minimal_gateway_options
    end    
    
    # Generates an ActiveMerchant compatible address hash from one of Spree's address objects
    def generate_address_hash(address)
      return {} if address.nil?
      { :name => address.full_name, 
        :lastname => address.lastname, 
        :firstnames => address.firstname, 
        :address1 => address.address1, 
        :address2 => address.address2, 
        :city => address.city,
        :state => address.state_text, 
        :state_abbr => address.state.nil? ? nil : address.state.abbr,
        :zip => address.zipcode, 
        :country => address.country.iso, 
        :phone => address.phone }
    end
    
    # Generates a minimal set of gateway options.  There appears to be some issues with passing in 
    # a billing address when authorizing/voiding a previously captured transaction.  So omits these 
    # options in this case since they aren't necessary.  
    def minimal_gateway_options
      {:email => order.user.email, 
       :customer => order.user.email, 
       :ip => order.ip_address, 
       :order_id => order.number, 	## OUT  + "_" + rand(1000).to_s, #pcc hack
       :shipping => order.ship_amount * 100,
       :tax => order.tax_amount * 100, 
       :subtotal => order.item_total * 100}  
    end
    
    # instantiates the selected gateway and configures with the options stored in the database
    def payment_gateway
      return Spree::BogusGateway.new if ENV['RAILS_ENV'] == "development" and Spree::Gateway::Config[:use_bogus]

      # retrieve gateway configuration from the database
      gateway_config = GatewayConfiguration.find :first
      config_options = {}
      gateway_config.gateway_option_values.each do |option_value|
        key = option_value.gateway_option.name.to_sym
        config_options[key] = option_value.value
      end
      gateway = gateway_config.gateway.clazz.constantize.new(config_options)

      return gateway
    end  
  end
end
