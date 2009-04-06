class RemoveRedundantProtxFields < ActiveRecord::Migration
  def self.up
    protx = Gateway.find_by_name('Protx')
    GatewayOption.find_all_by_gateway_id(protx.id).each {|o| o.destroy }    # also clears option values

    GatewayOption.create(:name => 'login', :description => 'Your Protx Vendor Name (note: remember to set the server IP addresses in your VSP account', :gateway => protx, :textarea => false)
  end

  def self.down
    # deliberately left blank because 'up' doesn't remove information
    # that is ever used in previous versions of the code.
  end
end
