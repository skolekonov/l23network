require 'spec_helper'
require 'yaml'
require 'puppetx/l23_hash_tools'

describe Puppet::Parser::Functions.function(:get_network_role_property) do
let(:network_scheme) do
<<eof
---
  version: 1.1
  provider: lnx
  interfaces:
    eth0:
      mtu: 2048
    eth1:
      mtu: 999
    eth2: {}
    eth3: {}
    eth4: {}
  transformations:
    - action: add-br
      name: br-storage
    - action: add-br
      name: br-ex
    - action: add-br
      name: br-mgmt
    - action: add-port
      name: eth4
      mtu: 777
    - action: add-port
      name: eth1.101
      bridge: br-mgmt
    - action: add-bond
      name: bond0
      bridge: br-storage
      interfaces:
        - eth2
        - eth3
      mtu: 4000
      bond_properties:
        mode: balance-rr
      interface_properties:
        mtu: 9000
        vendor_specific:
          disable_offloading: true
    - action: add-port
      name: bond0.102
      bridge: br-ex
    - action: add-br
      name: br-floating
      provider: ovs
    - action: add-patch
      bridges:
      - br-floating
      - br-ex
      provider: ovs
    - action: add-br
      name: br-prv
      provider: ovs
    - action: add-patch
      bridges:
      - br-prv
      - br-storage
      provider: ovs
  endpoints:
    eth0:
      IP: 'none'
    eth4:
      IP: 'none'
    br-ex:
      gateway: 10.1.3.1
      IP:
        - '10.1.3.11/24'
    br-storage:
      IP:
        - '10.1.2.11/24'
    br-mgmt:
      IP:
        - '10.1.1.11/24'
    br-floating:
      IP: none
    br-prv:
      IP: none
  roles:
    admin: eth0
    ex: br-ex
    management: br-mgmt
    storage: br-storage
    neutron/floating: br-floating
    neutron/private: br-prv
    xxx: eth4
eof
end



  let(:scope) { PuppetlabsSpec::PuppetInternals.scope }

  subject do
    function_name = Puppet::Parser::Functions.function(:get_network_role_property)
    scope.method(function_name)
  end

  context "get_network_role_property('**something_role**', 'phys_dev') usage" do
    before(:each) do
      scope.stubs(:lookupvar).with('l3_fqdn_hostname').returns('node1.tld')
      L23network::Scheme.set_config(
        scope.lookupvar('l3_fqdn_hostname'),
        L23network.sanitize_keys_in_hash(YAML.load(network_scheme))
      )
    end

    it 'should exist' do
      subject == Puppet::Parser::Functions.function(:get_network_role_property)
    end

    it 'should return physical device name for "management" network role (just subinterface)' do
      should run.with_params('management', 'phys_dev').and_return(["eth1"])
    end

    it 'should return physical device name for "ex" network role (subinterface of bond)' do
      should run.with_params('ex', 'phys_dev').and_return(["bond0", "eth2", "eth3"])
    end

    it 'should return physical device name for "floating" network role (OVS-bridge, connected by patch to LNX bridge)' do
      should run.with_params('neutron/floating', 'phys_dev').and_return(["bond0", "eth2", "eth3"])
    end

    it 'should return physical device name for "private" network role' do
      should run.with_params('neutron/private', 'phys_dev').and_return(["bond0", "eth2", "eth3"])
    end

    it 'should return physical device name for "storage" network role (bond, without tag)' do
      should run.with_params('storage', 'phys_dev').and_return(["bond0", "eth2", "eth3"])
    end

    it 'should return physical device name for "admin" network role (just interface has IP address)' do
      should run.with_params('admin', 'phys_dev').and_return(['eth0'])
    end

    it 'should return physical device name for untagged interface with simple transformation' do
      should run.with_params('xxx', 'phys_dev').and_return(['eth4'])
    end

    it 'should return NIL for "non-existent" network role' do
      should run.with_params('non-existent', 'phys_dev').and_return(nil)
    end
  end

end
