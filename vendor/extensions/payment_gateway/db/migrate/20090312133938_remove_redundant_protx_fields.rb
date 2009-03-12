class RemoveRedundantProtxFields < ActiveRecord::Migration
  def self.up
    protx = Gateway.find_by_name('protx')
    GatewayOption.find_by_gateway(protx).destroy
    GatewayOption.create(:name => 'login', :description => 'Your Protx Vendor Name (note: remember to set the server IP addresses in your VSP account', :gateway => protx, :textarea => false)
  end

  def self.down
    # deliberately left blank because 'up' doesn't remove information
    # that is ever used in previous versions of the code.
  end

  end
end
